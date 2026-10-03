# frozen_string_literal: true

module Api
  module V1
    module Parent
      # SCR-PAR-004 — Staff ↔ guardian messages about a child
      class CommunicationsController < BaseController
        before_action :guardian_student!, except: :mark_read

        # @oas_include
        # @summary Message thread between staff and the guardian for a child
        # @tags Parent Portal
        # @auth [bearer_jwt]
        # @parameter student_id(path) [!String] Student ID
        # @response Success (200) [Hash{ data: Array<Hash>, meta: Hash }]
        # @response Not Found (404) [Hash{ error: String }]
        # GET /api/v1/parent/students/:student_id/communications
        def index
          scope = @student.parent_communications
                          .for_guardian(current_guardian.id)
                          .includes(sender_user: %i[staff_member guardian])
                          .chronological
          messages, meta = paginated(scope)
          render json: { data: ParentCommunicationSerializer.new(messages).as_json, meta: meta }
        end

        # @oas_include
        # @summary Send a message to the therapy team about a child
        # @tags Parent Portal
        # @auth [bearer_jwt]
        # @parameter student_id(path) [!String] Student ID
        # @request_body Message [!Hash{ content: String }]
        # @request_body_example [JSON{ "content": "Can we discuss the new toileting goal?" }]
        # @response Created (201) [Hash{ data: Hash }]
        # @response Unprocessable Entity (422) [Hash{ error: Array<String> }]
        # POST /api/v1/parent/students/:student_id/communications
        def create
          message = @student.parent_communications.new(
            guardian: current_guardian,
            sender_user: current_user,
            direction: "inbound",
            kind: "general",
            content: params[:content].to_s.strip,
            sent_at: Time.current
          )

          if message.save
            render json: { data: ParentCommunicationSerializer.new(message).as_json }, status: :created
          else
            render_error(message.errors.full_messages, :unprocessable_entity)
          end
        end

        # @oas_include
        # @summary Mark a staff message as read
        # @tags Parent Portal
        # @auth [bearer_jwt]
        # @parameter id(path) [!String] Message ID
        # @response Success (200) [Hash{ data: Hash }]
        # @response Not Found (404) [Hash{ error: String }]
        # PATCH /api/v1/parent/communications/:id/mark_read
        def mark_read
          message = current_guardian.parent_communications.find_by(id: params[:id])
          return render_not_found("Message not found") unless message

          message.mark_read!
          render json: { data: ParentCommunicationSerializer.new(message).as_json }
        end
      end
    end
  end
end
