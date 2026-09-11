# frozen_string_literal: true

require "yaml"

class FreightPricingService
  CONFIG_PATH = Rails.root.join("config/freight_rates.yml")
  FALLBACK_LABEL = "Estimativa provisória — tabela de mercado ainda não ativada"

  def self.call(params:, route:, fallback:)
    new(params: params, route: route, fallback: fallback).call
  end

  def initialize(params:, route:, fallback:)
    @params = params || {}
    @route = route || {}
    @fallback = fallback || {}
  end

  def call
    return fallback_result unless enabled?

    # The commercial table is intentionally empty in Phase 1. Activation is
    # blocked until approved parameters and a traceable sample are supplied.
    insufficient_sample_result
  end

  private

  def config
    @config ||= YAML.safe_load(File.read(CONFIG_PATH), permitted_classes: [], aliases: false) || {}
  end

  def enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch("NATIONAL_FREIGHT_PRICING_ENABLED", config.fetch("enabled", false)))
  end

  def fallback_result
    {
      status: "fallback",
      label: FALLBACK_LABEL,
      source: "fórmula operacional existente; tabela comercial não ativada",
      reference_date: nil,
      sample_size: 0,
      sample_status: "insufficient",
      median: nil,
      p25: nil,
      p75: nil,
      suggested_value: @fallback[:valor_final],
      breakdown: fallback_breakdown
    }
  end

  def insufficient_sample_result
    {
      status: "insufficient_sample",
      label: "Amostra insuficiente",
      source: config["source"],
      reference_date: config["reference_date"],
      sample_size: config.fetch("sample_size", 0),
      sample_status: "insufficient",
      median: config.dig("parameters", "median"),
      p25: config.dig("parameters", "p25"),
      p75: config.dig("parameters", "p75"),
      suggested_value: nil,
      breakdown: {}
    }
  end

  def fallback_breakdown
    {
      distancia_km: @route[:distancia_km],
      duracao_minutos: @route[:duracao_minutos],
      peso_real: @params[:peso],
      peso_cubado: nil,
      peso_tarifavel: nil,
      custo_deslocamento: @fallback[:subtotal_km],
      adicional_peso: nil,
      adicional_volume: nil,
      pedagio: nil,
      retorno: nil,
      regiao: nil,
      tipo_carga: @params[:tipo_carga],
      urgencia: nil,
      tarifa_minima: @fallback[:taxa_minima],
      valor_sugerido: @fallback[:valor_final]
    }
  end
end
