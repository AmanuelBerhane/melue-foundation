# -*- encoding: utf-8 -*-
# stub: easy_talk_two 1.1.3 ruby lib

Gem::Specification.new do |s|
  s.name = "easy_talk_two".freeze
  s.version = "1.1.3".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "allowed_push_host" => "https://rubygems.org", "changelog_uri" => "https://github.com/a-chacon/easy_talk/blob/main/CHANGELOG.md", "homepage_uri" => "https://github.com/a-chacon/easy_talk", "source_code_uri" => "https://github.com/a-chacon/easy_talk" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["a-chacon".freeze]
  s.date = "1980-01-02"
  s.description = "Generate json-schema from plain Ruby classes.".freeze
  s.email = ["andres.ch@protonmail.com".freeze]
  s.homepage = "https://github.com/a-chacon/easy_talk".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.2".freeze)
  s.rubygems_version = "4.0.3".freeze
  s.summary = "Generate json-schema from Ruby classes.".freeze

  s.installed_by_version = "4.0.15".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<activemodel>.freeze, [">= 7.0".freeze])
  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 7.0".freeze])
  s.add_runtime_dependency(%q<sorbet-runtime>.freeze, [">= 0.5".freeze])
  s.add_development_dependency(%q<activerecord>.freeze, ["~> 7.0".freeze])
  s.add_development_dependency(%q<pry-byebug>.freeze, ["~> 3.10".freeze])
  s.add_development_dependency(%q<rake>.freeze, ["~> 13.1".freeze])
  s.add_development_dependency(%q<rspec>.freeze, ["~> 3.0".freeze])
  s.add_development_dependency(%q<rspec-json_expectations>.freeze, ["~> 2.0".freeze])
  s.add_development_dependency(%q<rspec-mocks>.freeze, ["~> 3.13".freeze])
  s.add_development_dependency(%q<rubocop>.freeze, ["~> 1.21".freeze])
  s.add_development_dependency(%q<rubocop-rake>.freeze, ["~> 0.6".freeze])
  s.add_development_dependency(%q<rubocop-rspec>.freeze, ["~> 2.29".freeze])
  s.add_development_dependency(%q<sqlite3>.freeze, ["~> 2".freeze])
end
