# db/seeds.rb

# === Usuário master Cliente ===================================
Cliente.find_or_create_by!(email: "master.cliente@cargaclick.com") do |c|
  c.nome = "Master Cliente"
  c.password = "12345678"
  c.password_confirmation = "12345678"
end
puts "✅ Cliente Master criado ou já existia"

# === Usuário master Transportador ============================
Transportador.find_or_create_by!(email: "master.transportador@cargaclick.com") do |t|
  t.nome = "Master Transportador"
  t.cpf = "12345678901" # CPF válido de exemplo (11 dígitos numéricos)
  t.tipo_veiculo = "Caminhão"
  t.password = "12345678"
  t.password_confirmation = "12345678"
  t.confirmed_at = Time.current
end
puts "✅ Transportador Master criado ou já existia"

# === Usuário master Admin ====================================
AdminUser.find_or_create_by!(email: "master.admin@cargaclick.com") do |a|
  a.password = "Admin123!"
  a.password_confirmation = "Admin123!"
  a.confirmed_at = Time.current if a.respond_to?(:confirmed_at)
end
puts "✅ Admin Master criado ou já existia"

AdminUser.create!(email: 'admin@example.com', password: 'password', password_confirmation: 'password') if Rails.env.development?
