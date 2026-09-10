# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "securerandom"

# Serviço de chat OpenAI-compatible com múltiplos provedores.
#
# Provedores (AI_PROVIDER):
#   - "ollama" (padrão; local/zero custo)
#   - "openai" | "groq" | "openrouter"
#
# ENV gerais:
#   AI_PROVIDER            (default: "ollama")
#   AI_MODEL               (override genérico de modelo)
#   AI_BASE_URL            (override genérico de base URL)
#   AI_TIMEOUT_S           (open/read) default: 20
#   AI_MAX_ATTEMPTS        (retries)   default: 3
#   AI_MAX_INPUT_CHARS     (limite de caracteres no input) default: 20000
#   AI_RESPONSE_JSON=1     (pede response_format json_object quando suportado)
#
# Por provedor:
#   OLLAMA_BASE_URL (default: http://127.0.0.1:11434)
#   OLLAMA_MODEL    (default: llama3.2:3b)
#   OLLAMA_FALLBACK_MODEL (default: llama3.2:1b)
#   OLLAMA_NUM_CTX, OLLAMA_SEED, OLLAMA_STOP="###|</s>"
#   OLLAMA_NATIVE=1  -> usa fallback nativo /api/chat se necessário
#
#   OPENAI_BASE_URL (default: https://api.openai.com), OPENAI_MODEL, OPENAI_API_KEY
#   GROQ_BASE_URL   (default: https://api.groq.com),   GROQ_MODEL,   GROQ_API_KEY
#   OPENROUTER_BASE_URL (default: https://openrouter.ai), OPENROUTER_MODEL, OPENROUTER_API_KEY
#
class GptService
  PROVIDER     = (ENV["AI_PROVIDER"] || "ollama").to_s.downcase.freeze
  TIMEOUT_S    = Integer(ENV.fetch("AI_TIMEOUT_S", ENV.fetch("OPENAI_TIMEOUT_S", "20")))
  MAX_ATTEMPTS = Integer(ENV.fetch("AI_MAX_ATTEMPTS", "3"))
  MAX_INPUT    = Integer(ENV.fetch("AI_MAX_INPUT_CHARS", "20000"))

  PROVIDERS = {
    "ollama" => {
      require_key: false,
      base:  -> { ENV["AI_BASE_URL"].presence || ENV.fetch("OLLAMA_BASE_URL", "http://127.0.0.1:11434") },
      path:  -> { "/v1/chat/completions" },
      model: -> { ENV["AI_MODEL"].presence || ENV.fetch("OLLAMA_MODEL", "llama3.2:3b") }
    },
    "openai" => {
      require_key: true,
      base:  -> { ENV["AI_BASE_URL"].presence || ENV.fetch("OPENAI_BASE_URL", "https://api.openai.com") },
      path:  -> { "/v1/chat/completions" },
      model: -> { ENV["AI_MODEL"].presence || ENV.fetch("OPENAI_MODEL", "gpt-4o-mini") },
      key:   -> {
        ENV["OPENAI_API_KEY"].presence ||
          begin
            Rails.application.credentials.dig(:openai, :api_key)
          rescue ActiveSupport::MessageEncryptor::InvalidMessage,
                 ActiveSupport::EncryptedFile::MissingContentError,
                 ArgumentError
            nil
          end
      }
    },
    "groq" => {
      require_key: true,
      base:  -> { ENV["AI_BASE_URL"].presence || ENV.fetch("GROQ_BASE_URL", "https://api.groq.com") },
      path:  -> { "/openai/v1/chat/completions" },
      model: -> { ENV["AI_MODEL"].presence || ENV.fetch("GROQ_MODEL", "llama-3.1-8b-instant") },
      key:   -> { ENV["GROQ_API_KEY"] }
    },
    "openrouter" => {
      require_key: true,
      base:  -> { ENV["AI_BASE_URL"].presence || ENV.fetch("OPENROUTER_BASE_URL", "https://openrouter.ai") },
      path:  -> { "/api/v1/chat/completions" },
      model: -> { ENV["AI_MODEL"].presence || ENV.fetch("OPENROUTER_MODEL", "meta-llama/llama-3.1-8b-instruct:free") },
      key:   -> { ENV["OPENROUTER_API_KEY"] }
    }
  }.freeze

  def initialize(prompt: nil, messages: nil, system: nil, model: nil,
                 temperature: 0.7, max_tokens: nil, top_p: nil, stream: false,
                 response_format: nil)
    @prompt      = prompt
    @messages    = messages
    @system      = system
    @model       = model # sobrescreve o default do provedor
    @temperature = temperature
    @max_tokens  = max_tokens
    @top_p       = top_p
    @stream      = stream
    @response_format = response_format # :json para JSON object quando suportado
  end

  # Uso:
  #   GptService.new(prompt: "Olá").call                # => String ou nil
  #   GptService.new(messages: [...], stream: true).call { |delta| ... }  # streaming
  def call(&on_chunk)
    request_id  = SecureRandom.hex(8)
    cfg         = PROVIDERS.fetch(PROVIDER) { PROVIDERS["ollama"] }

    base_url    = cfg[:base].call
    path        = cfg[:path].call
    model       = @model.presence || cfg[:model].call
    api_key     = cfg[:key]&.call
    require_key = cfg[:require_key]

    if require_key && api_key.to_s.strip.empty?
      Rails.logger.warn("AI[#{PROVIDER}] #{request_id} missing API key")
      return "IA indisponível no momento."
    end

    uri     = join_uri(base_url, path)
    headers = default_headers(api_key, request_id)
    body    = request_body(model)

    # OpenRouter: attribution opcional
    if PROVIDER == "openrouter"
      headers["HTTP-Referer"] = ENV["APP_URL"] if ENV["APP_URL"].present?
      headers["X-Title"]      = ENV["APP_NAME"] if ENV["APP_NAME"].present?
    end

    # 1ª tentativa (OpenAI-compatible)
    text, ok, status = do_request(uri, headers, body, request_id, &on_chunk)
    return text if ok

    # Fallback 1: pouca memória -> troca modelo (Ollama)
    if PROVIDER == "ollama" && (memory_error?(text) || status == 500)
      fb_model = ENV.fetch("OLLAMA_FALLBACK_MODEL", "llama3.2:1b")
      Rails.logger.warn("AI[ollama] #{request_id} retrying with fallback model: #{fb_model}")
      text, ok, _ = do_request(uri, headers, request_body(fb_model), request_id, &on_chunk)
      return text if ok
    end

    # Fallback 2 (opcional): usar API nativa do Ollama (/api/chat)
    if PROVIDER == "ollama" && ENV["OLLAMA_NATIVE"].to_s == "1"
      native_uri = join_uri(base_url, "/api/chat")
      Rails.logger.warn("AI[ollama] #{request_id} trying native /api/chat")
      text, ok = do_request_ollama_native(native_uri, headers, model, request_id, &on_chunk)
      return text if ok
    end

    nil
  rescue => e
    Rails.logger.error("AI[#{PROVIDER}] #{request_id} client error: #{e.class} - #{e.message}")
    nil
  end

  private

  # ---------- HTTP core ----------

  def do_request(uri, headers, body, request_id, &on_chunk)
    with_http(uri) do |http|
      attempt_with_retries(request_id: request_id) do
        req = Net::HTTP::Post.new(uri, headers)
        req.body = JSON.dump(body)

        if @stream
          aggregate = +""
          status = nil
          http.request(req) do |res|
            status = res.code.to_i
            ok = res.is_a?(Net::HTTPSuccess)
            unless ok
              msg = safe_body(res)
              Rails.logger.error("AI[#{PROVIDER}] #{request_id} HTTP #{res.code} #{msg}")
              return [msg, false, status]
            end

            res.read_body do |chunk|
              # Streaming OpenAI-style: linhas "data: {...}" terminadas com \n\n
              chunk.to_s.each_line do |line|
                next unless line.start_with?("data:")
                data = line.sub("data:", "").strip
                next if data == "[DONE]"
                json = JSON.parse(data) rescue nil
                delta = json&.dig("choices", 0, "delta", "content").to_s
                next if delta.empty?
                aggregate << delta
                on_chunk&.call(delta)
              end
            end
          end
          return [aggregate.presence, aggregate.present?, status]
        else
          res = http.request(req)
          status = res.code.to_i
          if res.is_a?(Net::HTTPSuccess)
            json = JSON.parse(res.body) rescue {}
            text = json.dig("choices", 0, "message", "content").to_s.strip
            return [text.presence, text.present?, status]
          else
            msg = safe_body(res)
            Rails.logger.error("AI[#{PROVIDER}] #{request_id} HTTP #{res.code} #{msg}")
            return [msg, false, status]
          end
        end
      end
    end
  end

  # API nativa do Ollama (/api/chat) — útil quando a OpenAI-compat não está disponível
  def do_request_ollama_native(uri, headers, model, request_id, &on_chunk)
    payload = {
      model: model,
      messages: clamp_messages(messages_for_body), # mesmo formato role/content
      options: ollama_options,
      stream: @stream ? true : false
    }

    with_http(uri) do |http|
      attempt_with_retries(request_id: request_id) do
        req = Net::HTTP::Post.new(uri, headers)
        req.body = JSON.dump(payload)

        if @stream
          aggregate = +""
          http.request(req) do |res|
            ok = res.is_a?(Net::HTTPSuccess)
            unless ok
              msg = safe_body(res)
              Rails.logger.error("AI[ollama] #{request_id} native HTTP #{res.code} #{msg}")
              return [msg, false]
            end
            res.read_body do |chunk|
              # nativo streama linhas JSON por vez
              chunk.to_s.each_line do |line|
                next if line.strip.empty?
                json = JSON.parse(line) rescue nil
                delta = json&.dig("message", "content").to_s
                next if delta.empty?
                aggregate << delta
                on_chunk&.call(delta)
              end
            end
          end
          return [aggregate.presence, aggregate.present?]
        else
          res = http.request(req)
          if res.is_a?(Net::HTTPSuccess)
            json = JSON.parse(res.body) rescue {}
            text = json.dig("message", "content").to_s.strip
            return [text.presence, text.present?]
          else
            msg = safe_body(res)
            Rails.logger.error("AI[ollama] #{request_id} native HTTP #{res.code} #{msg}")
            return [msg, false]
          end
        end
      end
    end
  end

  def with_http(uri)
    http = Net::HTTP.start(
      uri.host, uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: TIMEOUT_S,
      read_timeout: TIMEOUT_S
    )
    yield http
  ensure
    http&.finish if http&.active?
  end

  def attempt_with_retries(max_attempts: MAX_ATTEMPTS, base_delay: 0.5, request_id: "-")
    attempts = 0
    begin
      attempts += 1
      return yield
    rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ETIMEDOUT => e
      if attempts < max_attempts
        sleep base_delay * (2 ** (attempts - 1)) * (0.75 + rand * 0.5)
        Rails.logger.warn("AI[#{PROVIDER}] #{request_id} transient #{e.class} (#{attempts}/#{max_attempts}) retrying…")
        retry
      else
        Rails.logger.error("AI[#{PROVIDER}] #{request_id} transient failed: #{e.class} - #{e.message}")
        return [nil, false, 0]
      end
    end
  end

  # ---------- Payload & helpers ----------

  def request_body(model)
    body = {
      model:       model,
      messages:    clamp_messages(messages_for_body),
      temperature: @temperature
    }
    body[:max_tokens] = @max_tokens if @max_tokens
    body[:top_p]      = @top_p      if @top_p
    if json_response?
      body[:response_format] = { type: "json_object" }
    end
    # Extras para Ollama também via OpenAI-compat (alguns servidores aceitam)
    body[:options] = ollama_options.presence if PROVIDER == "ollama"
    body.compact
  end

  def messages_for_body
    if @messages.present?
      normalize_messages(@messages)
    else
      arr = []
      arr << { role: "system", content: @system } if @system.present?
      arr << { role: "user",   content: @prompt.to_s }
      arr
    end
  end

  def clamp_messages(msgs)
    # evita payload gigante em máquina com pouca RAM
    limit = MAX_INPUT
    msgs.map do |m|
      c = m[:content].to_s
      c = c.bytesize > limit ? c.byteslice(0, limit) + "…(truncated)" : c
      { role: m[:role].to_s.presence || "user", content: c }
    end
  end

  def normalize_messages(messages)
    Array(messages).map do |m|
      case m
      when String then { role: "user", content: m }
      when Hash   then { role: (m[:role] || m["role"]).to_s.presence || "user",
                          content: (m[:content] || m["content"]).to_s }
      else             { role: "user", content: m.to_s }
      end
    end.then { |arr| @system.present? ? [{ role: "system", content: @system }] + arr : arr }
  end

  def ollama_options
    return {} unless PROVIDER == "ollama"
    opts = {}
    if (ctx = ENV["OLLAMA_NUM_CTX"]).present?
      opts[:num_ctx] = Integer(ctx) rescue nil
    end
    opts[:num_predict] = @max_tokens if @max_tokens
    opts[:temperature] = @temperature if @temperature
    opts[:top_p]       = @top_p       if @top_p
    if (stops = ENV["OLLAMA_STOP"]).present?
      opts[:stop] = stops.split("|")
    end
    opts[:seed] = Integer(ENV["OLLAMA_SEED"]) rescue nil if ENV["OLLAMA_SEED"].present?
    opts.compact
  end

  def default_headers(api_key, request_id)
    h = {
      "Content-Type"  => "application/json",
      "Accept"        => "application/json",
      "User-Agent"    => "CargaclickAI/1.1 (+Rails)",
      "X-Request-ID"  => request_id
    }
    h["Authorization"] = "Bearer #{api_key}" if api_key.to_s.strip != ""
    h
  end

  def join_uri(base, path)
    base = base.end_with?("/") ? base.chomp("/") : base
    path = path.start_with?("/") ? path : "/#{path}"
    URI.parse("#{base}#{path}")
  end

  def safe_body(res)
    body = res.body.to_s
    body.bytesize > 2_000 ? body.byteslice(0, 2_000) + "…(truncated)" : body
  end

  def memory_error?(text)
    text.to_s.downcase.include?("requires more system memory")
  end

  def json_response?
    ENV["AI_RESPONSE_JSON"].to_s == "1" || @response_format.to_s == "json"
  end
end

