module Api
  module V1
    module Statuses
      class SeenController < BaseController
        before_action -> { doorkeeper_authorize! :write }
        before_action :require_user!

        def create
          status_ids = params[:ids]
          
          if status_ids.present?
            # Here you can implement the logic to mark statuses as seen
            # For example, you might want to store this in a database
            # or use it for analytics purposes
            render json: { success: true }
          else
            render json: { error: 'No status IDs provided' }, status: :unprocessable_entity
          end
        end
      end
    end
  end
end 