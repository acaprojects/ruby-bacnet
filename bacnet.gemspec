# frozen_string_literal: true, encoding: ASCII-8BIT

Gem::Specification.new do |s|
    s.name        = "bacnet"
    s.version     = '0.0.1'
    s.authors     = ["Stephen von Takach"]
    s.email       = ["steve@aca.im"]
    s.licenses    = ["MIT"]
    s.homepage    = "https://github.com/acaprojects/ruby-bacnet"
    s.summary     = "BACnet protocol on Ruby"
    s.description = <<-EOF
        Constructs BACnet standard datagrams that make it easy to communicate with devices on BACnet/IP networks
    EOF


    s.add_dependency 'bindata', '~> 2.3'

    s.add_development_dependency 'rspec', '~> 3.5'
    s.add_development_dependency 'yard',  '~> 0'
    s.add_development_dependency 'rake',  '~> 11'


    s.files = Dir["{lib}/**/*"] + %w(bacnet.gemspec README.md)
    s.test_files = Dir["spec/**/*"]
    s.extra_rdoc_files = ["README.md"]

    s.require_paths = ["lib"]
end
