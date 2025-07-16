class Api::V1::Timelines::AddToFeedController < Api::BaseController
    def create
        add_to_feed
    end

    # POST /api/v1/timelines/add_to_feed/batch
    # Expected params: { entries: [ { account_id: 1, status_id: 2, score: 10 }, ... ] }
    def batch
        entries = params[:entries]

        if entries.nil? || !entries.is_a?(Array)
            render json: { error: 'Entries must be an array' }, status: :bad_request and return
        end

        errors = []

        entries.each do |item|
            account_id = item[:account_id] || item['account_id']
            status_id  = item[:status_id]  || item['status_id']
            score      = item[:score]      || item['score']

            account = Account.find_by(id: account_id)
            status  = Status.find_by(id: status_id)

            if account.nil? || status.nil?
                errors << { account_id: account_id, status_id: status_id, error: 'Account or status not found' }
                next
            end

            result = FeedManager.instance.push_to_home(account, status, score: score)
            errors << { account_id: account_id, status_id: status_id, error: 'Failed to add' } unless result
        end

        if errors.empty?
            render json: { message: 'Statuses added to feeds' }, status: :accepted
        else
            render json: { errors: errors }, status: :multi_status
        end
    end

    def add_to_feed
        account_id = params[:account_id]
        status_id = params[:status_id]
        score = params[:score]

        if account_id.nil?
            render json: { error: "Account ID is required" }, status: :bad_request and return
        end 

        if status_id.nil?
            render json: { error: "Status ID is required" }, status: :bad_request and return
        end

        account = Account.find_by(id: account_id)
        if account.nil?
            render json: { error: "Account not found" }, status: :not_found and return
        end

        status = Status.find_by(id: status_id)
        if status.nil?
            render json: { error: "Status not found" }, status: :not_found and return
        end

        # unless current_user.admin? || current_user.account.id == account.id
        #   render json: { error: "Forbidden" }, status: :forbidden and return
        # end

        result = FeedManager.instance.push_to_home(account, status, score: score)
        if result
            render json: { message: "Status added to feed for account #{account.id}" }, status: :accepted
        else
            render json: { error: "Failed to add status to feed" }, status: :internal_server_error
        end
    end
end
