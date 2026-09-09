# frozen_string_literal: true

require "active_support/core_ext/integer/time"

Rails.application.configure do
  # =========================================================
  # BOOT
  # =========================================================
  config.enable_reloading = false
  config.eager_load       = true

  # =========================================================
  # ERROS / CACHE
  # =========================================================
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true
  config.cache_store = :memory_store

  # =========================================================
  # LOGS (🔥 RENDER / PRODUÇÃO)
  # =========================================================
  config.log_level = :info
  config.log_tags  = [:request_id]

  if ENV["RAILS_LOG_TO_STDOUT"].present?
    logger           = ActiveSupport::Logger.new(STDOUT)
    logger.formatter = config.log_formatter
    config.logger    = ActiveSupport::TaggedLogging.new(logger)
  end

  # =========================================================
  # ASSETS / STATIC FILES
  # =========================================================
  serve_static = ENV["RAILS_SERVE_STATIC_FILES"].present? ||
                 ENV["RENDER"].present?

  config.public_file_server.enabled = serve_static

  if serve_static
    max_age = 1.year.to_i
    config.public_file_server.headers = {
      "Cache-Control" => "public, max-age=#{max_age}"
    }
  end

  config.assets.compile = false

  # =========================================================
  # SSL
  # =========================================================
  config.force_ssl = ENV["FORCE_SSL"] == "true"

  # =========================================================
  # STORAGE
  # =========================================================
  config.active_storage.service = ENV["FLY_APP_NAME"].present? ? :fly_volume : :local

  # =========================================================
  # ACTION MAILER
  # =========================================================
  config.action_mailer.perform_caching = false

  # =========================================================
  # I18N
  # =========================================================
  config.i18n.default_locale = :"pt-BR"
  config.i18n.fallbacks      = true

  # =========================================================
  # DEPRECATIONS
  # =========================================================
  config.active_support.deprecation = :notify

  # =========================================================
  # SEGURANÇA
  # =========================================================
  config.require_master_key = ENV["CARGACLICK_ASSET_BUILD"] != "1" || ENV["FLY_APP_NAME"].present?
end
