# frozen_string_literal: true

module Admin
  class ManagementMetrics
    PERIODS = %w[today last_7_days last_30_days current_month previous_month custom].freeze

    attr_reader :start_at, :end_at, :previous_start_at, :previous_end_at, :period

    def initialize(period: "last_30_days", start_date: nil, end_date: nil, now: Time.current)
      @now = now.in_time_zone
      @period = PERIODS.include?(period.to_s) ? period.to_s : "last_30_days"
      @start_at, @end_at = resolve_range(start_date, end_date)
      duration = @end_at - @start_at
      @previous_end_at = @start_at - 1.second
      @previous_start_at = @previous_end_at - duration
    end

    def call
      current = snapshot(start_at, end_at)
      previous = snapshot(previous_start_at, previous_end_at)

      {
        period: period,
        range: { start: start_at.iso8601, end: end_at.iso8601 },
        previous_range: { start: previous_start_at.iso8601, end: previous_end_at.iso8601 },
        updated_at: @now.iso8601,
        sections: sections(current, previous)
      }
    end

    private

    def resolve_range(start_date, end_date)
      case period
      when "today"
        [@now.beginning_of_day, @now.end_of_day]
      when "last_7_days"
        [(@now.to_date - 6.days).beginning_of_day, @now.end_of_day]
      when "current_month"
        [@now.beginning_of_month, @now.end_of_day]
      when "previous_month"
        previous = @now.last_month
        [previous.beginning_of_month, previous.end_of_month]
      when "custom"
        custom_range(start_date, end_date)
      else
        [(@now.to_date - 29.days).beginning_of_day, @now.end_of_day]
      end
    end

    def custom_range(start_date, end_date)
      first = Date.iso8601(start_date.to_s)
      last = Date.iso8601(end_date.to_s)
      raise ArgumentError, "A data inicial deve ser anterior ou igual à data final" if first > last
      raise ArgumentError, "O período máximo é de 366 dias" if (last - first).to_i > 366

      [first.beginning_of_day.in_time_zone, last.end_of_day.in_time_zone]
    rescue Date::Error
      raise ArgumentError, "Informe datas válidas no formato AAAA-MM-DD"
    end

    def snapshot(first, last)
      freight = Frete.where(created_at: first..last)
      completed = Frete.where(status: "concluido").where("COALESCE(entregue_em, updated_at) BETWEEN ? AND ?", first, last)
      billed = Pagamento.where(status: "liberado").where("COALESCE(liberado_at, updated_at) BETWEEN ? AND ?", first, last)
      revenue = billed.sum(:valor).to_d
      billed_count = billed.count

      {
        revenue: revenue,
        active_clients: active_clients(first, last),
        active_carriers: active_carriers(first, last),
        moved_freight: completed.count,
        average_ticket: billed_count.positive? ? revenue / billed_count : nil,
        conversion_rate: percentage(completed.count, freight.count),
        leads: Lead.where(created_at: first..last).count,
        user_base_growth: user_base_growth(first, last),
        operations: completed.count
      }
    end

    def active_clients(first, last)
      Cliente.where(status_cadastro: Cliente.status_cadastros[:completo])
             .or(Cliente.where(id: Frete.where(created_at: first..last).select(:cliente_id)))
             .distinct.count
    end

    def active_carriers(first, last)
      Transportador.where("transportadores.status IN (?)", ["ativo", "0"])
                    .or(Transportador.where(id: Frete.where(created_at: first..last).select(:transportador_id)))
                    .distinct.count
    end

    def user_base_growth(first, last)
      initial = Cliente.where("created_at < ?", first).count + Transportador.where("created_at < ?", first).count
      final = Cliente.where("created_at <= ?", last).count + Transportador.where("created_at <= ?", last).count
      percentage(final - initial, initial)
    end

    def percentage(numerator, denominator)
      return nil unless denominator.to_d.positive?

      (numerator.to_d / denominator.to_d * 100).round(2)
    end

    def sections(current, previous)
      {
        commercial: [
          metric("Faturamento", current[:revenue], previous[:revenue], :currency, "Soma dos pagamentos liberados no período."),
          metric("Clientes ativos", current[:active_clients], previous[:active_clients], :number, "Clientes com cadastro completo ou frete criado no período."),
          metric("Transportadores ativos", current[:active_carriers], previous[:active_carriers], :number, "Transportadores ativos ou vinculados a fretes no período."),
          metric("Cargas movimentadas", current[:moved_freight], previous[:moved_freight], :number, "Fretes concluídos no período, pela data de entrega."),
          metric("Ticket médio", current[:average_ticket], previous[:average_ticket], :currency, "Faturamento dividido pelos pagamentos liberados."),
          metric("Taxa de conversão", current[:conversion_rate], previous[:conversion_rate], :percentage, "Fretes concluídos divididos pelos fretes criados no período.")
        ],
        marketing: [
          metric("Leads gerados", current[:leads], previous[:leads], :number, "Novos registros na base de leads."),
          unavailable("Custo de aquisição de clientes", "Não há registro de investimento em marketing."),
          unavailable("Conversão de campanhas", "Leads não possuem campanha e estado de conversão."),
          unavailable("Retorno sobre investimento", "Não há investimento nem receita atribuída a campanhas."),
          metric("Crescimento da base de usuários", current[:user_base_growth], previous[:user_base_growth], :percentage, "Variação de clientes e transportadores cadastrados entre o início e o fim do período.")
        ],
        operational: [
          metric("Operações realizadas", current[:operations], previous[:operations], :number, "Fretes concluídos no período."),
          unavailable("Taxa de atendimento", "O sistema não registra recebimento e conclusão de atendimentos."),
          unavailable("Tempo médio de atendimento", "O sistema não registra abertura e conclusão de atendimentos.")
        ]
      }
    end

    def metric(name, value, previous, format, description)
      comparison = if value.nil? || previous.nil? || previous.to_d.zero?
                     nil
                   else
                     ((value.to_d - previous.to_d) / previous.to_d.abs * 100).round(2)
                   end
      { name: name, value: value, format: format, comparison: comparison, trend: trend(comparison), description: description, available: !value.nil? }
    end

    def unavailable(name, reason)
      { name: name, value: nil, format: :number, comparison: nil, trend: :stable, description: reason, available: false }
    end

    def trend(comparison)
      return :stable if comparison.nil? || comparison.abs < 0.01

      comparison.positive? ? :up : :down
    end
  end
end
