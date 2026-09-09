"""Inspect a local image and exercise it using isolated, disposable Docker resources.

No production credentials, published ports, existing databases or volumes are used.
Run after: docker build -f Dockerfile.fly -t cargaclick-ci:check .
"""
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import sys
import tarfile
import tempfile
import time

IMAGE = sys.argv[1]
REPORT = Path('tmp/docker-validation.json')
REPORT.parent.mkdir(parents=True, exist_ok=True)
env = os.environ.copy()
generated = {name: secrets.token_hex(size) for name, size in
             [('SECRET_KEY_BASE', 64), ('RAILS_MASTER_KEY', 16), ('SMOKE_PASSWORD', 24)]}
env.update(generated)
report = {'image': IMAGE}


def run(args, *, input=None, check=True):
    result = subprocess.run(['docker', *args], input=input, capture_output=True,
                            text=True, env=env, timeout=240)
    if check and result.returncode:
        diagnostic = result.stdout + result.stderr
        for value in generated.values():
            diagnostic = diagnostic.replace(value, '[REDACTED]')
        print('\n'.join(diagnostic.splitlines()[-25:]))
        raise RuntimeError('Docker validation command failed')
    return result


def patterns(data):
    rules = {
        # MIME detection tables contain isolated PEM header strings, not keys.
        'private_key': rb'-----BEGIN ((?:[A-Z0-9]+ )*PRIVATE KEY)-----[ \t]*\r?\n(?:[A-Za-z0-9+/=,: -]+\r?\n|\r?\n)+-----END \1-----',
        'github_token': rb'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,})',
        'api_token': rb'\b(?:sk-(?:proj-)?[A-Za-z0-9_-]{40,}|AKIA[A-Z0-9]{16}|xox[baprs]-[A-Za-z0-9-]{20,})',
    }
    return [kind for kind, pattern in rules.items() if re.search(pattern, data)]


def inspect():
    findings = []
    layers = 0
    files = 0
    public_certificates = 0
    with tempfile.TemporaryDirectory(prefix='cargaclick-image-') as folder:
        archive = str(Path(folder) / 'image.tar')
        run(['image', 'save', '--output', archive, IMAGE])
        with tarfile.open(archive) as outer:
            manifest = json.load(outer.extractfile('manifest.json'))
            for entry in manifest:
                metadata = outer.extractfile(entry['Config']).read()
                findings.extend({'scope': 'metadata', 'kind': kind} for kind in patterns(metadata))
                for layer in entry['Layers']:
                    layers += 1
                    with tarfile.open(fileobj=outer.extractfile(layer), mode='r|*') as inner:
                        for member in inner:
                            name = member.name.removeprefix('./')
                            if not member.isfile() or not name.startswith(('app/', 'usr/local/bundle/')):
                                continue
                            files += 1
                            data = inner.extractfile(member).read()
                            forbidden = re.search(r'(^|/)(DeployRender|harleyjosesoncim|1234|local_secret\.txt|\.env(?:\..*)?|\.git|master[^/]*\.key)(/|$)', name)
                            forbidden = forbidden or re.search(r'\.(pem|p12|pfx|key|sqlite3|dump|log|bak|zip)$', name)
                            # Public signing certificates shipped by gems are not private credentials.
                            public_certificate = name.startswith('usr/local/bundle/') and name.endswith('.pem') and data.strip().startswith(b'-----BEGIN CERTIFICATE-----') and data.strip().endswith(b'-----END CERTIFICATE-----') and not patterns(data)
                            if public_certificate:
                                public_certificates += 1
                            safe_name = re.sub(r'(?:gh[pousr]_|github_pat_)[A-Za-z0-9_]+', '[REDACTED]', name)
                            if forbidden and not public_certificate:
                                findings.append({'layer': layers, 'file': safe_name, 'kind': 'forbidden_path'})
                            if not name.endswith('.enc'):
                                findings.extend({'layer': layers, 'file': safe_name, 'kind': kind} for kind in patterns(data))
    report['inspection'] = {'layers': layers, 'application_and_gem_files': files, 'findings': findings,
                            'public_signing_certificates': public_certificates,
                            'scope': 'metadata, application and gems in every layer, including deleted files'}
    if findings:
        raise RuntimeError('Sensitive material found in image layers; no values printed')


def smoke():
    suffix = secrets.token_hex(6)
    network = 'cargaclick-ci-' + suffix
    db = network + '-db'
    web = network + '-web'
    created = []
    credentials = tempfile.TemporaryDirectory(prefix='cargaclick-test-credentials-')
    try:
        # A random master key cannot decrypt the repository's real ciphertext.
        # Mount a matching synthetic encrypted file for this isolated test only.
        generator = "ActiveSupport::EncryptedFile.new(content_path: '/validation/credentials.yml.enc', key_path: '/validation/unused.key', env_key: 'RAILS_MASTER_KEY', raise_if_missing_key: true).write(\"{}\\n\"); File.chmod(0644, '/validation/credentials.yml.enc')"
        run(['run', '--rm', '--network', 'none', '-e', 'RAILS_MASTER_KEY',
             '--mount', 'type=bind,src=' + credentials.name + ',dst=/validation', IMAGE,
             'bundle', 'exec', 'ruby', '-r', 'active_support', '-r', 'active_support/encrypted_file', '-e', generator])
        encrypted_path = str(Path(credentials.name) / 'credentials.yml.enc')
        run(['network', 'create', '--internal', network])
        created.append(('network', network))
        run(['run', '-d', '--name', db, '--network', network, '--tmpfs', '/var/lib/postgresql/data',
             '-e', 'POSTGRES_HOST_AUTH_METHOD=trust', '-e', 'POSTGRES_DB=cargaclick_image_validation', 'postgres:16'])
        created.append(('container', db))
        for _ in range(60):
            if run(['exec', db, 'pg_isready', '-U', 'postgres'], check=False).returncode == 0:
                break
            time.sleep(1)
        else:
            raise RuntimeError('Isolated database not ready')
        args = ['--network', network, '-e', 'DATABASE_URL=postgresql://postgres@' + db + '/cargaclick_image_validation',
                '--mount', 'type=bind,src=' + encrypted_path + ',dst=/app/config/credentials.yml.enc,readonly',
                '-e', 'SECRET_KEY_BASE', '-e', 'RAILS_MASTER_KEY', '-e', 'SMOKE_PASSWORD',
                '-e', 'FLY_APP_NAME=cargaclick-ci', '-e', 'FORCE_SSL=true', '-e', 'WEB_CONCURRENCY=1']
        run(['run', '--rm', *args, '-e', 'DISABLE_DATABASE_ENVIRONMENT_CHECK=1', IMAGE,
             'bundle', 'exec', 'rails', 'db:schema:load'])
        run(['run', '-d', '--name', web, *args, '--tmpfs', '/data', IMAGE])
        created.append(('container', web))
        for _ in range(60):
            response = run(['exec', web, 'curl', '-s', '-o', '/dev/null', '-w', '%{http_code}',
                            '-H', 'X-Forwarded-Proto: https', 'http://127.0.0.1:8080/up'], check=False)
            if response.stdout.strip() == '200':
                break
            time.sleep(1)
        else:
            raise RuntimeError('Production image did not become healthy')
        result = run(['exec', '-i', web, 'bundle', 'exec', 'rails', 'runner', '-'],
                     input=Path('test/docker/smoke.rb').read_text())
        report['smoke'] = json.loads(next(line.removeprefix('SMOKE_REPORT=') for line in
                                          result.stdout.splitlines() if line.startswith('SMOKE_REPORT=')))
        report['smoke']['credentials'] = 'matching synthetic encrypted credentials mounted read-only; no production secrets'
    finally:
        for kind, name in reversed(created):
            run(['network', 'rm', name] if kind == 'network' else ['rm', '-f', name], check=False)
        credentials.cleanup()


try:
    report['image_id'] = run(['image', 'inspect', IMAGE, '--format', '{{.Id}}']).stdout.strip()
    inspect()
    smoke()
    report['passed'] = True
finally:
    REPORT.write_text(json.dumps(report, indent=2))
    print(json.dumps(report))
