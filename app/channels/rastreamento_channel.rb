class RastreamentoChannel < ApplicationCable::Channel
  def subscribed
    frete = Frete.find_by(id: params[:frete_id])
    return reject unless frete && authorized_for?(frete)

    stream_from "rastreamento_#{frete.id}"
  end

  private

  def authorized_for?(frete)
    current_user.is_a?(AdminUser) ||
      (current_user.is_a?(Cliente) && frete.cliente_id == current_user.id) ||
      (current_user.is_a?(Transportador) && frete.transportador_id == current_user.id)
  end
end
