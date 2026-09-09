require 'net/http'
require 'nokogiri'
ActionMailer::Base.delivery_method = :test
ActiveJob::Base.queue_adapter = :test
raise 'Unexpected database' unless ActiveRecord::Base.connection_db_config.database == 'cargaclick_image_validation'
report = { database: ActiveRecord::Base.connection.select_value('SELECT 1') == 1 }
admin = AdminUser.create!(email: 'image-check@example.invalid', password: ENV.fetch('SMOKE_PASSWORD'))
cookies = {}
request = lambda do |path, form = nil|
  uri = URI("http://127.0.0.1:8080#{path}")
  req = form ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
  req['Host'] = 'cargaclick.fly.dev'
  req['X-Forwarded-Proto'] = 'https'
  req['Cookie'] = cookies.map { |k,v| "#{k}=#{v}" }.join('; ')
  req.set_form_data(form) if form
  response = Net::HTTP.start(uri.hostname, uri.port) { |http| http.request(req) }
  response.get_fields('set-cookie').to_a.each do |cookie|
    key,value = cookie.split(';',2).first.split('=',2)
    cookies[key] = value
  end
  response
end
report[:up] = request.call('/up').code.to_i
home = request.call('/')
report[:home] = home.code.to_i
report[:anonymous_admin] = request.call('/admin/atendimentos_gerenciais').code.to_i
login = request.call('/admin/login')
report[:login_page] = login.code.to_i
token = Nokogiri::HTML(login.body).at_css('input[name="authenticity_token"]')&.[]('value')
raise 'Missing CSRF token' unless token
signed_in = request.call('/admin/login', {'authenticity_token'=>token, 'admin_user[email]'=>admin.email, 'admin_user[password]'=>ENV.fetch('SMOKE_PASSWORD')})
report[:authentication] = signed_in.code.to_i
dashboard = request.call('/admin/atendimentos_gerenciais')
report[:admin] = dashboard.code.to_i
report[:admin_cards] = Nokogiri::HTML(dashboard.body).css('.mgmt-card').length
assets = [home,dashboard].flat_map do |response|
 doc=Nokogiri::HTML(response.body)
 doc.css('link[rel="stylesheet"],script[src]').map { |node| node['href'] || node['src'] }
end.select { |path| path.start_with?('/assets/') }.uniq
report[:assets] = assets.map { |path| { path: path, status: request.call(path).code.to_i } }
before = Frete.count
frete = Frete.create!(origem: 'Smoke Origem', destino: 'Smoke Destino')
frete.reload.update!(origem: 'Smoke Consulta')
report[:essential_operation] = frete.reload.pagamento_aguardando? && Frete.count == before + 1
puts 'SMOKE_REPORT=' + report.to_json
raise 'Smoke failed' unless report.values_at(:up,:home,:login_page,:admin).all? { |s| s == 200 } && [302,303].include?(report[:authentication]) && [302,303].include?(report[:anonymous_admin]) && report[:admin_cards] >= 14 && assets.any? { |p| p.end_with?('.css') } && assets.any? { |p| p.end_with?('.js') } && report[:assets].all? { |a| a[:status] == 200 } && report[:essential_operation]
