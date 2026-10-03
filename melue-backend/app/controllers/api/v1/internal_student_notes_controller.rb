# frozen_string_literal: true

module Api
  module V1
    class InternalStudentNotesController < BaseController
      before_action :authenticate_user!
      before_action :require_director_or_admin

      # @oas_include
      # @summary List all internal notes for a student (FR-135)
      # @tags Internal Student Notes
      # @auth [bearer_jwt]
      # @parameter student_id(path) [String] Required. UUID of the student.
      # @response Success (200) [Array<Hash>]
      # @response_example Success (200) [JSON{
      #   "data": [
      #     {
      #       "id": "uuid",
      #       "student_id": "uuid",
      #       "author_id": "uuid",
      #       "author_name": "Dr. Sarah",
      #       "author_role": "Program Director",
      #       "content": "Reviewing progress — recommend transition to Functional Living next semester.",
      #       "recorded_at": "2026-09-29T10:00:00Z",
      #       "created_at": "2026-09-29T10:00:00Z"
      #     }
      #   ]
      # }]
      # @response Forbidden (403) [Hash]
      # @response Not Found (404) [Hash]
      def index
        result = ::Students::InternalNotesService.list(
          student_id: params[:student_id],
          current_user: current_user
        )

        if result.success?
          render json: { data: InternalStudentNoteSerializer.new(result.data).as_json }, status: :ok
        else
          render_error_response(result)
        end
      end

      # @oas_include
      # @summary Create an internal note for a student (FR-135)
      # @tags Internal Student Notes
      # @auth [bearer_jwt]
      # @parameter student_id(path) [String] Required. UUID of the student.
      # @request_body [Hash] Note parameters
      # @request_body_example [JSON{ "content": "Clinical review notes — student showing strong improvement in vocal imitation.", "recorded_at": "2026-09-29T10:00:00Z" }]
      # @response Created (201) [Hash]
      # @response Forbidden (403) [Hash]
      # @response Unprocessable Entity (422) [Hash]
      def create
        result = ::Students::InternalNotesService.create(
          student_id: params[:student_id],
          current_user: current_user,
          params: note_params
        )

        if result.success?
          render json: { data: InternalStudentNoteSerializer.new(result.data).as_json }, status: :created
        else
          render_error_response(result)
        end
      end

      # @oas_include
      # @summary Update an internal note for a student (FR-135)
      # @tags Internal Student Notes
      # @auth [bearer_jwt]
      # @parameter student_id(path) [String] Required. UUID of the student.
      # @parameter id(path) [String] Required. UUID of the note.
      # @request_body [Hash] Note update parameters
      # @request_body_example [JSON{ "content": "Updated clinical observation." }]
      # @response Success (200) [Hash]
      # @response Forbidden (403) [Hash]
      # @response Not Found (404) [Hash]
      def update
        result = ::Students::InternalNotesService.update(
          student_id: params[:student_id],
          note_id: params[:id],
          current_user: current_user,
          params: note_params
        )

        if result.success?
          render json: { data: InternalStudentNoteSerializer.new(result.data).as_json }, status: :ok
        else
          render_error_response(result)
        end
      end

      # @oas_include
      # @summary Delete an internal note for a student (FR-135)
      # @tags Internal Student Notes
      # @auth [bearer_jwt]
      # @parameter student_id(path) [String] Required. UUID of the student.
      # @parameter id(path) [String] Required. UUID of the note.
      # @response Success (200) [Hash]
      # @response Forbidden (403) [Hash]
      # @response Not Found (404) [Hash]
      def destroy
        result = ::Students::InternalNotesService.destroy(
          student_id: params[:student_id],
          note_id: params[:id],
          current_user: current_user
        )

        if result.success?
          render json: { message: result.data[:message] }, status: :ok
        else
          render_error_response(result)
        end
      end

      private

      def note_params
        params.permit(:content, :recorded_at).to_h.symbolize_keys
      end

      def render_error_response(result)
        render json: { error: result.error }, status: result.status || status_for(result.error)
      end

      def status_for(error)
        case error
        when /forbidden/i then :forbidden
        when /not found/i then :not_found
        else :unprocessable_entity
        end
      end
    end
  end
end
