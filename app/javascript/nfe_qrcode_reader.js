import { BrowserQRCodeReader } from "@zxing/browser"

let activeControls

function stopCamera() {
  activeControls?.stop()
  activeControls = undefined
  document.querySelectorAll("[data-camera-video]").forEach((video) => {
    video.srcObject?.getTracks().forEach((track) => track.stop())
    video.srcObject = null
  })
}

function initializeReader() {
  const root = document.querySelector("[data-nfe-reader]")
  if (!root || root.dataset.initialized) return
  root.dataset.initialized = "true"

  const input = root.querySelector("[data-qr-input]")
  const status = root.querySelector("[data-reader-status]")
  const panel = root.querySelector("[data-camera-panel]")
  const video = root.querySelector("[data-camera-video]")
  const reader = new BrowserQRCodeReader()

  const found = (text) => {
    input.value = text
    status.textContent = "QR Code lido. Confira o conteúdo e clique em Continuar."
    stopCamera()
    panel.hidden = true
    input.focus()
  }

  root.querySelector("[data-camera-open]")?.addEventListener("click", async () => {
    status.textContent = "Solicitando acesso à câmera…"
    panel.hidden = false
    try {
      activeControls = await reader.decodeFromConstraints(
        { video: { facingMode: { ideal: "environment" } }, audio: false },
        video,
        (result) => { if (result) found(result.getText()) }
      )
      status.textContent = "Aponte a câmera traseira para o QR Code."
    } catch (_error) {
      stopCamera()
      panel.hidden = true
      status.textContent = "Não foi possível acessar a câmera. Autorize a permissão ou use a entrada manual."
    }
  })

  root.querySelector("[data-camera-close]")?.addEventListener("click", () => {
    stopCamera()
    panel.hidden = true
    status.textContent = "Leitor fechado. Você pode continuar manualmente."
  })

  root.querySelector("[data-qr-image]")?.addEventListener("change", async (event) => {
    const file = event.target.files?.[0]
    if (!file) return
    status.textContent = "Lendo a foto neste aparelho…"
    const url = URL.createObjectURL(file)
    try {
      const result = await reader.decodeFromImageUrl(url)
      found(result.getText())
    } catch (_error) {
      status.textContent = "QR Code não encontrado na foto. Tente outra imagem ou use a entrada manual."
    } finally {
      URL.revokeObjectURL(url)
      event.target.value = ""
    }
  })
}

document.addEventListener("DOMContentLoaded", initializeReader)
document.addEventListener("turbo:load", initializeReader)
document.addEventListener("turbo:before-cache", stopCamera)
window.addEventListener("pagehide", stopCamera)
