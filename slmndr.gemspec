Gem::Specification.new do |s|
  s.name        = 'slmndr'
  s.version     = '0.0.1'
  s.date        = '2015-06-30'
  s.summary     = "Salamander"
  s.description = "A minimalistic ruby web crawling framework. See https://github.com/penafieljlm/slmndr for more information."
  s.authors     = ["John Lawrence M. Penafiel"]
  s.email       = 'penafieljlm@gmail.com'
  s.files       = ["lib/slmndr.rb"]
  s.homepage    = 'http://rubygems.org/gems/slmndr'
  s.license     = 'MIT'
  s.cert_chain  = ['certs/penafieljlm.pem']
  s.signing_key = File.expand_path("~/.ssh/gem-private_key.pem") if $0 =~ /gem\z/
end