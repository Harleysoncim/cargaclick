# frozen_string_literal: true

class FreightPricingStatisticsService
  Result = Struct.new(
    :sample_size, :median, :p25, :p75, :sample_status, :criteria,
    keyword_init: true
  )

  def self.call(scope:, filters: {})
    new(scope: scope, filters: filters).call
  end

  def initialize(scope:, filters: {})
    @scope = scope
    @filters = filters.compact
  end

  def call
    comparable = comparable_records
    values = comparable.filter_map { |record| decimal_value(value_for(record)) }.sort
    minimum = configured_minimum_sample

    Result.new(
      sample_size: values.length,
      median: percentile(values, 0.50),
      p25: percentile(values, 0.25),
      p75: percentile(values, 0.75),
      sample_status: values.length >= minimum ? "sufficient" : "insufficient",
      criteria: @filters
    )
  end

  private

  def comparable_records
    records = @scope.respond_to?(:to_a) ? @scope.to_a : Array(@scope)
    records.select do |record|
      @filters.all? { |field, expected| read_value(record, field).to_s == expected.to_s }
    end
  end

  def value_for(record)
    read_value(record, :valor_aceito).presence ||
      read_value(record, :valor_cotado).presence ||
      read_value(record, :valor)
  end

  def read_value(record, field)
    record.respond_to?(field) ? record.public_send(field) : record[field.to_s] || record[field]
  end

  def decimal_value(value)
    BigDecimal(value.to_s) if value.present?
  rescue ArgumentError
    nil
  end

  def configured_minimum_sample
    config = YAML.safe_load(
      File.read(Rails.root.join("config/freight_rates.yml")),
      permitted_classes: [],
      aliases: false
    ) || {}
    Integer(config["minimum_sample_size"] || 0)
  end

  def percentile(values, percentile)
    return nil if values.empty?

    rank = (values.length - 1) * percentile
    lower = values[rank.floor]
    upper = values[rank.ceil]
    ((lower + upper) / 2).round(2)
  end
end
