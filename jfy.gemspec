# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jfy/version'

Gem::Specification.new do |spec|
  spec.name          = 'jfy'
  spec.version       = Jfy::VERSION
  spec.authors       = ['John Ferlito']
  spec.email         = ['johnf@inodes.org']

  spec.summary       = %q{Library to speak to JFY Solar Inverters over a serial port}
  spec.homepage      = 'https://github.com/johnf/jfy'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.10'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rspec'
end
