module Api
  module V1
    class SyncsController < BaseController
      # @oas_include
      # @summary Fetch modified records since last sync
      # @tags Offline Sync Endpoints
      # @auth [bearer_jwt]
      # @parameter last_synced_at(query) [String] The ISO8601 timestamp of the client's last sync
      # @response Success (200) [Hash{server_timestamp: String, data: Hash}]
      def pull
        result = SyncData::PullService.call(params[:last_synced_at])
        if result.success?
          render json: result.data
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end

      # @oas_include
      # @summary Push offline mutations to the server
      # @tags Offline Sync Endpoints
      # @auth [bearer_jwt]
      # @request_body payload [Hash{client_timestamp: String, mutations: Array<Hash>}]
      # @response Success (200) [Hash{server_timestamp: String}]
      def push
        result = SyncData::PushService.call(request.request_parameters)
        if result.success?
          render json: result.data
        else
          render json: { error: result.error }, status: :unprocessable_entity
        end
      end
    end
  end
end
