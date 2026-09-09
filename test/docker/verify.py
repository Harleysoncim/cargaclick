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
        'private_key': rb'-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----',
        'github_token': rb'\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,})',
        'api_token': rb'\b(?:sk-(?:proj-)?[A-Za-z0-9_-]{40,}|AKIA[A-Z0-9]{16}|xox[baprs]-[A-Za-z0-9-]{20,})',
    }
    return [kind for kind, pattern in rules.items() if re.search(pattern, data)]


def inspect():
    findings = []
    layers = 0
    files = 0
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
                            if not member.isfile() or not name.startswith('app/'):
                                continue
                            files += 1
                            forbidden = re.search(r'(^|/)(DeployRender|harleyjosesoncim|1234|local_secret\.txt|\.env(?:\..*)?|\.git|master[^/]*\.key)(/|$)', name)
                            forbidden = forbidden or re.search(r'\.(pem|p12|pfx|key|sqlite3|dump|log|bak|zip)$', name)
                            if forbidden:
                                findings.append({'layer': layers, 'kind': 'forbidden_path'})
                            if not name.endswith('.enc'):
                                data = inner.extractfile(member).read()
                                findings.extend({'layer': layers, 'kind': kind} for kind in patterns(data))
    report['inspection'] = {'layers': layers, 'application_files': files, 'findings': findings,
                            'scope': 'metadata and application contents in every layer, including deleted files'}
    if findings:
        raise RuntimeError('Sensitive material found in image layers; no values printed')


def smoke():
    suffix = secrets.token_hex(6)
    network = 'cargaclick-ci-' + suffix
    db = network + '-db'
    web = network + '-web'
    created = []
    try:
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
    finally:
        for kind, name in reversed(created):
            run(['network', 'rm', name] if kind == 'network' else ['rm', '-f', name], check=False)


try:
    report['image_id'] = run(['image', 'inspect', IMAGE, '--format', '{{.Id}}']).stdout.strip()
    inspect()
    smoke()
    report['passed'] = True
finally:
    REPORT.write_text(json.dumps(report, indent=2))
    print(json.dumps(report))
