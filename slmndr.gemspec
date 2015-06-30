Gem::Specification.new do |s|
  s.name        = 'slmndr'
  s.version     = '0.0.4'
  s.date        = '2015-06-30'
  s.summary     = "Salamander"
  s.description = "A minimalistic ruby web crawling framework.\nSee https://github.com/penafieljlm/slmndr for more information."
  s.authors     = ["John Lawrence M. Penafiel"]
  s.email       = 'penafieljlm@gmail.com'
  s.files       = ["lib/slmndr.rb"]
  s.homepage    = 'http://rubygems.org/gems/slmndr'
  s.license     = 'MIT'
  s.cert_chain  = ['certs/penafieljlm.pem']
  s.signing_key = File.expand_path("~/.ssh/gem-private_key.pem") if $0 =~ /gem\z/
  s.add_runtime_dependency 'json', '~> 1.8', '>= 1.8.3'
  s.add_runtime_dependency 'open_uri_redirections', '~> 0.2', '>= 0.2.1'
  s.add_runtime_dependency 'nokogiri', '~> 1.6', '>= 1.6.6.2'
  s.add_runtime_dependency 'addressable', '~> 2.3', '>= 2.3.8'
end