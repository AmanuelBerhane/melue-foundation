# Only load FactoryBot configuration in test environment.
if Rails.env.test?
  FactoryBot.definition_file_paths = [ Rails.root.join("test/factories") ]
end
