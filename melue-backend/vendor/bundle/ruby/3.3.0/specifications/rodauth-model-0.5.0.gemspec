# -*- encoding: utf-8 -*-
# stub: rodauth-model 0.5.0 ruby lib

Gem::Specification.new do |s|
  s.name = "rodauth-model".freeze
  s.version = "0.5.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "source_code_uri" => "https://github.com/janko/rodauth-model" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Janko Marohni\u0107".freeze]
  s.date = "1980-01-02"
  s.description = "Provides model mixin for Active Record and Sequel that defines password attribute and associations based on Rodauth configuration.".freeze
  s.email = ["janko@hey.com".freeze]
  s.homepage = "https://github.com/janko/rodauth-model".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5".freeze)
  s.rubygems_version = "4.0.13".freeze
  s.summary = "Provides model mixin for Active Record and Sequel that defines password attribute and associations based on Rodauth configuration.".freeze

  s.installed_by_version = "4.0.15".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<rodauth>.freeze, ["~> 2.28".freeze])
  s.add_development_dependency(%q<minitest>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<minitest-hooks>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<bcrypt>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<jwt>.freeze, ["< 2.10".freeze])
  s.add_development_dependency(%q<rotp>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<rqrcode>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<webauthn>.freeze, [">= 0".freeze])
end
