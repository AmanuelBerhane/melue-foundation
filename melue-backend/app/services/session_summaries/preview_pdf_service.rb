# frozen_string_literal: true

module SessionSummaries
  # Handles PDF preview generation. Returns 501 Not Implemented (Option B)
  # since PDF rendering libraries are not yet installed in the application.
  class PreviewPdfService < ApplicationService
    def initialize(session:)
      @session = session
    end

    def call
      failure("PDF generation is not implemented yet")
    end
  end
end
