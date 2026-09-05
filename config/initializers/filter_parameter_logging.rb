# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn,
  :nfe_chave_acesso, :nfe_qrcode_text, :nfe_emitente_documento,
  :seguro_valor_carga, :seguro_valor_premio, :seguro_numero_cotacao,
  :seguro_descricao_mercadoria
]
