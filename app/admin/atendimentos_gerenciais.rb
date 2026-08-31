# frozen_string_literal: true

ActiveAdmin.register_page "Atendimentos Gerenciais" do
  menu priority: 2, label: "Atendimentos Gerenciais"

  controller do
    def index
      @management_metrics = metrics_service.call
      super
    rescue ArgumentError => e
      redirect_to admin_atendimentos_gerenciais_path, alert: e.message
    end

    private

    def metrics_service
      Admin::ManagementMetrics.new(
        period: params[:period],
        start_date: params[:start_date],
        end_date: params[:end_date]
      )
    end
  end

  page_action :data, method: :get do
    payload = Admin::ManagementMetrics.new(
      period: params[:period],
      start_date: params[:start_date],
      end_date: params[:end_date]
    ).call
    render json: payload
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  content title: "Atendimentos Gerenciais" do
    render partial: "admin/atendimentos_gerenciais/dashboard", locals: { dashboard: @management_metrics }
  end
end
