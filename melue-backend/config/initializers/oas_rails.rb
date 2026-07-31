# frozen_string_literal: true

# OpenAPI Specification configuration for Melue Foundation API
OasRails.configure do |config|
  # ==============================================================================
  # API Info & Metadata
  # ==============================================================================

  config.info.title = "Melue Foundation Therapy Management API"
  config.info.summary = "REST API for therapy management system"
  config.info.description = <<~DESC.strip
    REST API for the Melue Foundation Therapy Management System.
    Manages identity, student enrollment, clinical assessments, IUP authoring,
    active therapy sessions, scheduling, and reporting.
  DESC

  config.info.contact.name = "Melue Foundation"
  config.info.contact.email = "api@melue.foundation"

  # ==============================================================================
  # Server Configuration
  # ==============================================================================

  config.servers = [
    {
      url: "http://localhost:3000/api/v1",
      description: "Local development server"
    },
    {
      url: "https://api.melue.foundation/api/v1",
      description: "Production server"
    }
  ]

  # ==============================================================================
  # API Tags & Organization
  # ==============================================================================

  config.tags = [
    {
      name: "Authentication",
      description: "Login and password reset operations"
    },
    {
      name: "Users",
      description: "User account management"
    },
    {
      name: "Configuration",
      description: "System configuration and reference data"
    },
    {
      name: "Students",
      description: "Student registration and enrollment"
    },
    {
      name: "Assessment",
      description: "Six-week clinical assessments"
    },
    {
      name: "IUP & Goals",
      description: "Individualized treatment plans and goals"
    },
    {
      name: "Scheduling",
      description: "Teacher-student scheduling and assignments"
    },
    {
      name: "Active Therapy",
      description: "Therapy sessions, trials, and incidents"
    },
    {
      name: "Communication",
      description: "Notifications and parent communication"
    }
  ]

  # ==============================================================================
  # Route Filtering & Inclusion
  # ==============================================================================

  # Only include routes that start with /api/v1
  config.api_path = "/api/v1"

  # Only include explicitly tagged endpoints
  config.include_mode = :explicit

  # Exclude Rodauth routes from documentation (they're already documented)
  config.ignored_actions = [
    "rodauth"
  ]

  # ==============================================================================
  # Authentication Settings
  # ==============================================================================

  # Don't authenticate routes by default (set per-endpoint with @auth tag)
  config.authenticate_all_routes_by_default = false

  # Use JWT bearer token as the default security schema
  config.security_schema = :bearer_jwt

  # Custom security schemas (optional - for additional auth methods)
  config.security_schemas = {
    bearer_jwt: {
      type: :http,
      scheme: :bearer,
      bearerFormat: "JWT",
      description: "JWT token obtained from /api/v1/auth/login"
    }
  }

  # ==============================================================================
  # Default Error Responses
  # ==============================================================================

  # Add default error responses to endpoints
  config.set_default_responses = true

  # Possible default error responses
  config.possible_default_responses = [
    :not_found,
    :unauthorized,
    :forbidden,
    :internal_server_error,
    :unprocessable_entity
  ]

  # Response body template for default errors
  config.response_body_of_default = "Hash{ error: String }"

  # ==============================================================================
  # UI Configuration
  # ==============================================================================

  # Use the Rails-themed RapiDoc UI
  config.rapidoc_theme = "rails"

  # ==============================================================================
  # Source OAS Configuration
  # ==============================================================================

  # Reference a JSON file containing reusable OAS components (schemas, etc.)
  # Note: Must be valid JSON format, not YAML
  config.source_oas_path = "docs/oas_rails/melue.oas.json"

  # ==============================================================================
  # Project License
  # ==============================================================================

  config.info.license.name = "MIT"
  config.info.license.url = "https://opensource.org/licenses/MIT"
end
