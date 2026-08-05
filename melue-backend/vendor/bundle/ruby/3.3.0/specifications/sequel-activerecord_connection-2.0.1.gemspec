# -*- encoding: utf-8 -*-
# stub: sequel-activerecord_connection 2.0.1 ruby lib

Gem::Specification.new do |s|
  s.name = "sequel-activerecord_connection".freeze
  s.version = "2.0.1".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Janko Marohni\u0107".freeze]
  s.date = "1980-01-02"
  s.description = "Allows Sequel to use ActiveRecord connection for database interaction.".freeze
  s.email = ["janko@hey.com".freeze]
  s.homepage = "https://github.com/janko/sequel-activerecord_connection".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 2.5".freeze)
  s.rubygems_version = "3.6.9".freeze
  s.summary = "Allows Sequel to use ActiveRecord connection for database interaction.".freeze

  s.installed_by_version = "4.0.15".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<sequel>.freeze, ["~> 5.38".freeze])
  s.add_runtime_dependency(%q<activerecord>.freeze, [">= 5.1".freeze])
  s.add_development_dependency(%q<sequel_pg>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<minitest>.freeze, [">= 0".freeze])
  s.add_development_dependency(%q<warning>.freeze, [">= 0".freeze])
end
