document.addEventListener('DOMContentLoaded', () => {
  const map = L.map('map').setView([-23.5505, -46.6333], 13); // Exemplo inicial São Paulo

  // Tiles do mapa (OpenStreetMap)
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap contributors'
  }).addTo(map);

  // Coordenadas exemplo (substituir por reais)
  const origem = [-23.5505, -46.6333];
  const destino = [-23.5705, -46.6433];

  L.marker(origem).addTo(map).bindPopup('Origem');
  L.marker(destino).addTo(map).bindPopup('Destino');

  // Rotas devem ser calculadas exclusivamente pelo backend autenticado.
  // Este protótipo não consulta provedores externos nem contém chaves de API.

  // Marcador do Transportador (posição inicial exemplo)
  let transportadorMarker = L.marker([-23.5605, -46.6383], { 
    icon: L.icon({
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/3082/3082383.png',
      iconSize: [40, 40]
    })
  }).addTo(map).bindPopup('Transportador');

  // Atualização dinâmica via backend Rails
  const freteId = window.location.pathname.split('/').slice(-2)[0]; // captura ID da URL atual (ex: /fretes/123/rastreamento)

  const atualizarLocalizacao = () => {
    fetch(`/fretes/${freteId}/localizacao_transportador`)
      .then(response => response.json())
      .then(data => {
        const novaPosicao = [data.latitude, data.longitude];
        transportadorMarker.setLatLng(novaPosicao);
        map.panTo(novaPosicao);
      })
      .catch(error => console.error('Erro ao atualizar posição:', error));
  };

  // Atualiza localização a cada 15 segundos
  setInterval(atualizarLocalizacao, 15000);
});
