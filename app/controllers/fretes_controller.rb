# frozen_string_literal: true

class FretesController < ApplicationController
  # ==================================================
  # CALLBACKS
  # ==================================================
  before_action :set_frete, only: %i[
    show edit update destroy chat rastreamento
  ]
  before_action :authorize_frete!, only: %i[show edit update destroy chat]
  before_action :authorize_rastreamento!, only: :rastreamento

  # ==================================================
  # FORMULÁRIO PÚBLICO — SIMULAÇÃO
  # Botão: "Simular frete"
  # Rota: GET /simular-frete
  # ==================================================
  def new
    # Apenas renderiza o formulário de simulação
    # Não depende de model
  end

  # ==================================================
  # SIMULAÇÃO DE FRETE — PROCESSAMENTO
  # Botões envolvidos:
  # - "Calcular frete"
  # - "Nova simulação"
  #
  # Resultado:
  # - render :resultado
  # ==================================================
  def simular
    parametros = parametros_simulacao

    # ---------- validação mínima (ANTI-500) ----------
    if parametros[:origem].blank? || parametros[:destino].blank?
      flash[:alert] = "Informe origem e destino para simular o frete."
      return redirect_to simular_frete_path
    end

    # ---------- cálculo ----------
    @resultado = CalcularFrete.call(parametros)

    unless @resultado[:sucesso]
      Rails.logger.warn(
        "[FretesController#simular][ERRO] #{@resultado[:mensagem]} | #{@resultado[:detalhes]}"
      )
      flash[:alert] = @resultado[:mensagem] || "Não foi possível simular o frete."
      return render :new, status: :unprocessable_entity
    end

    # ---------- transportadores disponíveis ----------
    # (usado APENAS para exibição, sem compromisso)
    @transportadores =
      Transportador
        .where(status: :ativo, status_cadastro: :completo)
        .limit(5)

    Rails.logger.info(
      "[FretesController#simular][OK] " \
      "valor=#{@resultado[:valor_total]} " \
      "transportadores=#{@transportadores.pluck(:id)}"
    )

    render :resultado, status: :ok

  rescue StandardError => e
    Rails.logger.error(
      "[FretesController#simular][FATAL] #{e.class}: #{e.message}"
    )
    render "errors/500", status: :internal_server_error
  end

  # ==================================================
  # CONTRATAÇÃO REAL DO FRETE
  # Botão: "Contratar frete"
  # Só aparece para cliente logado
  # ==================================================
  def create
    authenticate_cliente!

    # SECURITY: Link frete to quotation for price integrity.
    # Accept either: (1) explicit cotacao_id (preferred) or (2) valor from form
    # if quotation validation is available. This maintains backward compatibility
    # while encouraging use of quotation-based pricing.
    cotacao_id = frete_params[:cotacao_id]

    if cotacao_id.present?
      # Preferred path: Explicit quotation link
      cotacao = Cotacao.find_by(id: cotacao_id)
      unless cotacao_from_validated_simulation?(cotacao)
        flash[:alert] = "Cotação inválida ou expirada. Refaça a simulação."
        return redirect_to simular_frete_path
      end

      # Price from quotation (verified server-side)
      price_value = cotacao.valor
      cotacao_link = cotacao
    else
      # Backward compatibility: Allow valor from form, but it's not verified.
      # This is less secure but maintains compatibility with existing forms.
      # FUTURE: Deprecate this path in favor of quotation-based pricing.
      if params.dig(:frete, :valor).present?
        Rails.logger.warn(
          "[FretesController#create] Using browser-supplied valor (unverified) " \
          "from Cliente ##{current_cliente.id}. Prefer quotation-based pricing."
        )
        price_value = params[:frete][:valor]
        cotacao_link = nil
      else
        flash[:alert] = "Cotação inválida. Refaça a simulação."
        return redirect_to simular_frete_path
      end
    end

    @frete = Frete.new(frete_params.except(:cotacao_id))
    @frete.cliente = current_cliente
    @frete.valor = price_value
    @frete.valor_estimado = price_value
    @frete.cotacao = cotacao_link

    if @frete.save
      redirect_to @frete, notice: "Frete contratado com sucesso."
    else
      Rails.logger.warn(
        "[FretesController#create] #{@frete.errors.full_messages.join(', ')}"
      )
      flash.now[:alert] = "Não foi possível contratar o frete."
      render :new, status: :unprocessable_entity
    end
  end

  # ==================================================
  # CRUD — SÓ EXISTE SE TIVER BOTÃO
  # ==================================================
  def show; end
  def edit; end

  def update
    if @frete.update(frete_params)
      redirect_to @frete, notice: "Frete atualizado com sucesso."
    else
      flash.now[:alert] = "Erro ao atualizar o frete."
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @frete.destroy
    redirect_to inicio_path, notice: "Frete removido."
  end

  # ==================================================
  # FUNCIONALIDADES ATIVAS (SEM PROMESSA FALSA)
  # ==================================================
  def chat; end
  def rastreamento; end

  private

  # ==================================================
  # VALIDAÇÃO DE COTAÇÃO
  # ==================================================
  def cotacao_from_validated_simulation?(cotacao)
    cotacao.present? && cotacao.valid_for_contract?
  end

  # ==================================================
  # PARÂMETROS DE SIMULAÇÃO
  # ==================================================
  def parametros_simulacao
    {
      origem:       params[:origem].to_s.strip,
      destino:      params[:destino].to_s.strip,
      peso:         params[:peso].presence,
      volume:       params[:volume].presence,
      tipo_veiculo: params[:tipo_veiculo].presence,
      tipo_carga:   params[:tipo_carga].presence
    }
  end

  # ==================================================
  # BUSCA SEGURA (ANTI-500)
  # ==================================================
  def set_frete
    @frete = Frete.find_by(id: params[:id])
    return if @frete.present?

    redirect_to inicio_path, alert: "Frete não encontrado."
  end

  def authorize_frete!
    return if current_admin_user.present?
    return if current_cliente.present? && @frete.cliente_id == current_cliente.id
    return if current_transportador.present? && @frete.transportador_id == current_transportador.id

    head :not_found
  end

  def authorize_rastreamento!
    authenticated = current_cliente.present? ||
                    current_transportador.present? ||
                    current_admin_user.present?

    unless authenticated
      redirect_to root_path, alert: "Faça login para acessar o rastreamento."
      return
    end

    authorized = current_admin_user.present? ||
                 (current_cliente.present? && @frete.cliente_id == current_cliente.id) ||
                 (current_transportador.present? && @frete.transportador_id == current_transportador.id)

    head :not_found unless authorized
  end

  # ==================================================
  # STRONG PARAMS — CONTRATAÇÃO
  # ==================================================
  def frete_params
    params.require(:frete).permit(
      :origem,
      :destino,
      :peso,
      :volume,
      :tipo_carga,
      :tipo_veiculo,
      :descricao,
      :cotacao_id,
      :valor
    )
  end
end
