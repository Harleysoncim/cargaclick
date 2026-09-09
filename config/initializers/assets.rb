# config/initializers/assets.rb
# frozen_string_literal: true

Rails.application.config.assets.version = "1.0"

# Onde esbuild / tailwindcss-rails gravam os bundles fingerprintados
Rails.application.config.assets.paths << Rails.root.join("app/assets/builds")

# Manifests extras além de application.(css|js)
Rails.application.config.assets.precompile += %w[
  active_admin.css
  active_admin.js
  tailwind.css
  leaflet.css
  inter-font.css
]
