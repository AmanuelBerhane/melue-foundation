# -*- encoding: utf-8 -*-
# stub: oas_core 1.4.0 ruby lib

Gem::Specification.new do |s|
  s.name = "oas_core".freeze
  s.version = "1.4.0".freeze

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "changelog_uri" => "https://github.com/a-chacon/oas_core/blob/main/CHANGELOG.md", "homepage_uri" => "https://github.com/a-chacon/oas_core", "rubygems_mfa_required" => "true", "source_code_uri" => "https://github.com/a-chacon/oas_core" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["a-chacon".freeze]
  s.date = "1980-01-02"
  s.description = "OasCore simplifies API documentation by automatically generating OpenAPI Specification (OAS 3.2) documents from your Ruby application routes. It eliminates the need for manual documentation, ensuring accuracy and consistency.".freeze
  s.email = ["andres.ch@protonmail.com".freeze]
  s.homepage = "https://github.com/a-chacon/oas_core".freeze
  s.licenses = ["GPL-3.0-only".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.1".freeze)
  s.rubygems_version = "3.6.7".freeze
  s.summary = "Generates OpenAPI Specification (OAS) documents by analyzing and extracting routes from Rails applications.".freeze

  s.installed_by_version = "4.0.15".freeze

  s.specification_version = 4

  s.add_runtime_dependency(%q<activesupport>.freeze, [">= 7.0".freeze])
  s.add_runtime_dependency(%q<deep_merge>.freeze, ["~> 1.2".freeze, ">= 1.2.2".freeze])
  s.add_runtime_dependency(%q<method_source>.freeze, ["~> 1.0".freeze])
  s.add_runtime_dependency(%q<yard>.freeze, ["~> 0.9".freeze])
end
