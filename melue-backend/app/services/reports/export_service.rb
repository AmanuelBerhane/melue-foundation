require "csv"

module Reports
  class ExportService < ApplicationService
    def initialize(data:, format:, report_type: "report")
      @data = data
      @format = format.to_s.downcase
      @report_type = report_type
    end

    def call
      case @format
      when "csv"
        success(generate_csv)
      when "pdf"
        success(generate_pdf)
      else
        failure("Unsupported export format: #{@format}")
      end
    rescue StandardError => e
      failure(e.message)
    end

    private

    def generate_csv
      return "" if @data.blank?

      # If the data is an array of records (e.g., Session Summaries)
      if @data.is_a?(Array) && @data.first.is_a?(Hash)
        headers = extract_headers(@data.first)

        CSV.generate(headers: true) do |csv|
          csv << headers
          @data.each do |row|
            csv << flatten_hash(row).values_at(*headers)
          end
        end
      else
        # Fallback for singular complex reports (e.g., Foundation Overview)
        CSV.generate do |csv|
          csv << [ "Metric", "Value" ]
          flatten_hash(@data).each do |key, value|
            csv << [ key.to_s.titleize, value ]
          end
        end
      end
    end

    def generate_pdf
      # TODO: PDF generation architecture stub.
      # Needs a library like Prawn or WickedPDF added to the Gemfile.
      # For now, we return a stubbed string to represent the PDF binary content.
      "PDF generation is pending implementation of a PDF library (e.g., prawn or wicked_pdf)."
    end

    def extract_headers(hash)
      flatten_hash(hash).keys
    end

    def flatten_hash(hash, prefix = nil)
      hash.each_with_object({}) do |(k, v), result|
        key = prefix ? "#{prefix}.#{k}" : k.to_s
        if v.is_a?(Hash)
          result.merge!(flatten_hash(v, key))
        elsif v.is_a?(Array)
          # Convert arrays to comma-separated strings to fit in a single CSV cell
          result[key] = v.map { |i| i.is_a?(Hash) ? i.to_json : i.to_s }.join(", ")
        else
          result[key] = v
        end
      end
    end
  end
end
