// app/javascript/application.js

console.log("Hello from CargoClick Rails 7 with ESBuild!");

// Importa apenas o JS do Leaflet (não o CSS, pois ele já está no <head> do HTML)
import L from 'leaflet';
import './nfe_qrcode_reader';

// Quando o DOM carregar, configura o mapa de cadastro de transportador (se existir o elemento)
document.addEventListener('DOMContentLoaded', () => {
  const cepInput = document.getElementById('cep_input');
  const enderecoInput = document.getElementById('endereco_input');
  const mapElement = document.getElementById('map');

  if (cepInput && enderecoInput && mapElement) {
    // Inicia o mapa centrado em São Paulo
    const map = L.map('map').setView([-23.5505, -46.6333], 12);

    // Adiciona camada OpenStreetMap
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap contributors'
    }).addTo(map);

    // Adiciona marcador padrão
    let marker = L.marker([-23.5505, -46.6333]).addTo(map);

    // Busca endereço no Nominatim ao sair do campo CEP
    cepInput.addEventListener('blur', function () {
      const cep = this.value.trim().replace(/\D/g, '');

      if (cep.length === 8) {
        fetch(`https://nominatim.openstreetmap.org/search?format=json&q=${cep}+Brasil`)
          .then(res => res.json())
          .then(data => {
            if (data.length > 0) {
              const { lat, lon, display_name } = data[0];
              const coords = [parseFloat(lat), parseFloat(lon)];

              marker.setLatLng(coords);
              map.setView(coords, 15);

              enderecoInput.value = display_name;
            } else {
              alert("Endereço não encontrado para o CEP informado.");
            }
          });
      }
    });
  }
});
import "./channels"
