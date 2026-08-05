# -*- encoding: utf-8 -*-
# stub: oas_rails 1.4.0 ruby lib

Gem::Specification.new do |s|
  s.name = "oas_rails".freeze
  s.version = "1.4.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "homepage_uri" => "https://github.com/a-chacon/oas_rails" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["a-chacon".freeze]
  s.date = "1980-01-02"
  s.description = "OasRails is a Rails engine for generating automatic interactive documentation for your Rails APIs. It generates an OAS 3.1 document and displays it using RapiDoc.".freeze
  s.email = ["andres.ch@protonmail.com".freeze]
  s.homepage = "https://github.com/a-chacon/oas_rails".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.1".freeze)
  s.rubygems_version = "3.6.7".freeze
  s.summary = "OasRails is a Rails engine for generating automatic interactive documentation for your Rails APIs.".freeze

  s.installed_by_version = "4.0.15".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<easy_talk_two>.freeze, ["~> 1.1.3".freeze])
  s.add_runtime_dependency(%q<oas_core>.freeze, [">= 1.1.0".freeze])
end
