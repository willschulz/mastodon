# frozen_string_literal: true

class Api::V1::Timelines::PublicController < Api::BaseController
  before_action :require_user!, only: [:show], if: :require_auth?
  after_action :insert_pagination_headers, unless: -> { @statuses.empty? }

  def show
    @statuses = load_statuses
    
    ###
    #weighted_scores = calculate_weighted_scores(@statuses)
    #@statuses = @statuses.sort_by { |status| [-weighted_scores[status.id], -status.created_at.to_i] }
    #insert_pagination_headers #this is suggested but doesn't make sense to me
    ###
    faves = Array.new(@statuses.length)
    for ii in 0...@statuses.length
      faves[ii] = REST::StatusSerializer.new(@statuses[ii]).favourites_count
    end
    
    faves_json = faves.to_json
    puts <<~JS
      <script>
        var faves = #{faves_json};
        console.log(faves);
      </script>
    JS
    
    statuses_with_favorites = Status.where(id: @statuses).select(:id, :favourites_count)
    #faves = statuses_with_favorites.map { |status| status.favourites_count }
    
    sorted_statuses = @statuses.sort_by.with_index { |_, i| -faves[i] } 
    @statuses = sorted_statuses
    render json: @statuses, each_serializer: REST::StatusSerializer, relationships: StatusRelationshipsPresenter.new(@statuses, current_user&.account_id)
  end

  private
  
  ###
  #def calculate_weighted_scores(statuses)
  #  # Calculate the weighted scores for each status
  #  statuses.map do |status|
  #    likes_count = REST::StatusSerializer.new(status).favourites_count# || 0
  #    #retweets_count = status.retweets_count || 0
  #    #replies_count = status.replies_count || 0
  #    likes_weight = 0.5
  #    retweets_weight = 0.3
  #    replies_weight = 0.2
  #    weighted_score = likes_count * likes_weight #+ retweets_count * retweets_weight + replies_count * replies_weight
  #    [status.id, weighted_score]
  #end.to_h
  ###

  def require_auth?
    !Setting.timeline_preview
  end

  def load_statuses
    cached_public_statuses_page
  end

  def cached_public_statuses_page
    cache_collection(public_statuses, Status)
  end

  def public_statuses
    public_feed.get(
      limit_param(100),
      params[:max_id],
      params[:since_id],
      params[:min_id]
    )
  end

  def public_feed
    PublicFeed.new(
      current_account,
      local: truthy_param?(:local),
      remote: truthy_param?(:remote),
      only_media: truthy_param?(:only_media)
    )
  end

  def insert_pagination_headers
    set_pagination_headers(next_path, prev_path)
  end

  def pagination_params(core_params)
    params.slice(:local, :remote, :limit, :only_media).permit(:local, :remote, :limit, :only_media).merge(core_params)
  end

  def next_path
    api_v1_timelines_public_url pagination_params(max_id: pagination_max_id)
  end

  def prev_path
    api_v1_timelines_public_url pagination_params(min_id: pagination_since_id)
  end

  def pagination_max_id
    @statuses.last.id
  end

  def pagination_since_id
    @statuses.first.id
  end
end
