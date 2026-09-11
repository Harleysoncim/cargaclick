import L from "leaflet"

const initializeRouteMap = () => {
  const modal = document.querySelector("[data-route-map-modal]")
  const openButton = document.querySelector("[data-route-map-open]")
  const closeButton = modal?.querySelector("[data-route-map-close]")
  const canvas = modal?.querySelector("[data-route-map-canvas]")
  const dataElement = modal?.querySelector("[data-route-map-data]")

  if (!modal || !openButton || !closeButton || !canvas || !dataElement || modal.dataset.initialized) return

  let map
  modal.dataset.initialized = "true"

  const close = () => {
    modal.classList.add("hidden")
    openButton.focus()
  }

  const open = () => {
    modal.classList.remove("hidden")
    if (!map) {
      const data = JSON.parse(dataElement.textContent)
      map = L.map(canvas, { zoomControl: true, scrollWheelZoom: true })
      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: "&copy; OpenStreetMap contributors"
      }).addTo(map)

      const route = L.geoJSON(data.geojson, { style: { color: "#2563eb", weight: 5 } }).addTo(map)
      const origin = L.latLng(data.origem_coords[1], data.origem_coords[0])
      const destination = L.latLng(data.destino_coords[1], data.destino_coords[0])
      const popup = (label, value) => {
        const element = document.createElement("span")
        element.textContent = `${label}: ${value}`
        return element
      }
      L.marker(origin).addTo(map).bindPopup(popup("Origem", data.origem))
      L.marker(destination).addTo(map).bindPopup(popup("Destino", data.destino))
      map.fitBounds(route.getBounds(), { padding: [24, 24] })
    }
    window.requestAnimationFrame(() => map.invalidateSize())
    closeButton.focus()
  }

  openButton.addEventListener("click", open)
  closeButton.addEventListener("click", close)
  modal.addEventListener("click", (event) => {
    if (event.target === modal) close()
  })
  modal.addEventListener("keydown", (event) => {
    if (event.key === "Escape") close()
  })

  if (modal.hasAttribute("data-route-map-auto-open")) open()
}

document.addEventListener("turbo:load", initializeRouteMap)
document.addEventListener("DOMContentLoaded", initializeRouteMap)
