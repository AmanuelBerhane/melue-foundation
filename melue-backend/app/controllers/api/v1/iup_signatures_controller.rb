# frozen_string_literal: true

module Api
  module V1
    class IupSignaturesController < Api::V1::BaseController
      before_action :authenticate_user!
      before_action :set_iup
      before_action :ensure_iup_is_draft

      def create
        result = Iups::SignatureService.call(
          iup: @iup,
          signer_user: current_user,
          signer_role: params[:signer_role],
          signature_evidence: params[:signature_evidence]
        )

        if result.success?
          signature = result.data[:signature]
          render json: {
            signature: {
              id: signature.id,
              iup_id: signature.iup_id,
              signer_role: signature.signer_role,
              signer_name: signature.signer_name,
              signed_at: signature.signed_at
            }
          }, status: :created
        else
          render_error(result.error, :unprocessable_content)
        end
      end

      private

      def set_iup
        @iup = Iup.kept.find_by(id: params[:iup_id])
        render_not_found("IUP not found") unless @iup
      end

      def ensure_iup_is_draft
        unless @iup&.status_draft?
          render_error("Signatures can only be added to draft IUPs", :unprocessable_content)
        end
      end
    end
  end
end
