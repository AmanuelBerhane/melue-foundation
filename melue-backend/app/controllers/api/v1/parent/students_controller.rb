# frozen_string_literal: true

module Api
  module V1
    module Parent
      # SCR-PAR-002 — the guardian's children
      class StudentsController < BaseController
        before_action :guardian_student!, only: :show

        # @oas_include
        # @summary List the signed-in guardian's children
        # @tags Parent Portal
        # @auth [bearer_jwt]
        # @parameter limit(query) [Integer] Page size (max 100). default: (20)
        # @parameter offset(query) [Integer] Records to skip. default: (0)
        # @response Success (200) [Hash{ data: Array<Hash>, meta: Hash }]
        # GET /api/v1/parent/students
        def index
          students, meta = paginated(current_guardian.students.kept.order(:first_name, :last_name))
          render json: { data: StudentSerializer.new(students).as_json, meta: meta }
        end

        # @oas_include
        # @summary Full profile of one of the guardian's children
        # @tags Parent Portal
        # @auth [bearer_jwt]
        # @parameter id(path) [!String] Student ID
        # @response Success (200) [Hash{ data: Hash }]
        # @response Not Found (404) [Hash{ error: String }]
        # GET /api/v1/parent/students/:id
        def show
          render json: { data: StudentSerializer.new(@student, profile: true).as_json }
        end
      end
    end
  end
end
