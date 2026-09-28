# app/services/students/caseload_service.rb
module Students
  class CaseloadService < ApplicationService
    attr_reader :program_director, :filters

    def initialize(program_director, filters = {})
      @program_director = program_director
      @filters = filters
    end

    def call
      return failure("Program Director not found") unless program_director&.role_program_director?

      students = fetch_students
      success(students)
    end

    private

    def fetch_students
      # Get students with active IUPs
      students = Student
        .joins(:iups)
        .where(iups: { status: "active" })
        .distinct

      # Filter by search term
      if filters[:search].present?
        students = students.search_by_name(filters[:search])
      end

      # Filter by program type
      if filters[:program_type].present?
        students = students.by_program_type(filters[:program_type])
      end

      # Filter by therapy group
      if filters[:therapy_group].present?
        students = students.by_therapy_group(filters[:therapy_group])
      end

      # Filter by status
      if filters[:status].present?
        students = students.where(status: filters[:status])
      end

      students.order(:last_name, :first_name)
    end
  end
end
