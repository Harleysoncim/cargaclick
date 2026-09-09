class CheckoutController < ApplicationController
  before_action :authenticate_cliente!
  before_action :set_frete

  def show
  end

  def pix
    @frete.update!(status_pagamento: :aguardando)

    @qr_code = "00020126330014BR.GOV.BCB.PIX0114+558199999999520400005303986540#{@frete.valor_total.to_i}5802BR5920CargaClick6009SAO PAULO62070503***6304ABCD"
    render :show
  end

  private

  def set_frete
    @frete = Frete.find(params[:id])
  end
end
