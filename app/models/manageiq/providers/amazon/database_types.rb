# frozen_string_literal: true

module ManageIQ::Providers::Amazon::DatabaseTypes
  ALL_TYPES = YAML.load_file(
    ManageIQ::Providers::Amazon::Engine.root.join('db/fixtures/aws_database_types.yml')
  )

  def self.database_types
    ALL_TYPES
  end

  def self.all
    database_types.values
  end
end
