# frozen_string_literal: true

module Paginable
  extend ActiveSupport::Concern

  included do
    scope :paginate_by_max_id, ->(limit, max_id = nil, since_id = nil) {
      query = order(arel_table[:id].desc).limit(limit)
      query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      query = query.where(arel_table[:id].gt(since_id)) if since_id.present?
      query
    }

    # Differs from :paginate_by_max_id in that it gives the results immediately following min_id,
    # whereas since_id gives the items with largest id, but with since_id as a cutoff.
    # Results will be in ascending order by id.
    scope :paginate_by_min_id, ->(limit, min_id = nil, max_id = nil) {
      query = reorder(arel_table[:id]).limit(limit)
      query = query.where(arel_table[:id].gt(min_id)) if min_id.present?
      query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      query
    }

    # ## This works!  But it's really weird to solve it by treating like counts as a time interval, rather than age as a bigint...
    scope :paginate_by_age_and_likes, ->(limit, max_id = nil, since_id = nil) {
      query = left_joins(:status_stat)
      coalesced_favourites_count = Arel::Nodes::NamedFunction.new('COALESCE', [StatusStat.arel_table[:favourites_count], Arel::Nodes.build_quoted(0)])
    
      # Multiply the favourites count by 3600 and convert to interval
      weighted_favourites_count = coalesced_favourites_count * 60*10
      interval_seconds = Arel::Nodes::NamedFunction.new('MAKE_INTERVAL', [Arel::Nodes.build_quoted(0), Arel::Nodes.build_quoted(0), Arel::Nodes.build_quoted(0), Arel::Nodes.build_quoted(0), Arel::Nodes.build_quoted(0), Arel::Nodes.build_quoted(0), weighted_favourites_count])
    
      current_time = Arel::Nodes.build_quoted(DateTime.now)
      created_at_column = arel_table[:created_at]
    
      age_in_seconds = current_time - created_at_column
    
      # Subtract the interval of weighted favourites from age in seconds
      score = age_in_seconds - interval_seconds
    
      # Order by score ascending and limit the result
      query = query.reorder(score.asc).limit(limit)
    
      query
    }

    def self.to_a_paginated_by_id(limit, options = {})#still need this? how to paginate this way for rchron and my new way by timeline interface?
      if options[:min_id].present?
        paginate_by_min_id(limit, options[:min_id], options[:max_id]).reverse
      else
        paginate_by_max_id(limit, options[:max_id], options[:since_id]).to_a
      end
    end
    
    def self.to_a_paginated_by_id_fav(limit, options = {})
      if options[:min_id].present?
        paginate_by_min_id(limit, options[:min_id], options[:max_id]).reverse
      else
        paginate_by_max_id_fav(limit, options[:max_id], options[:since_id]).to_a
      end
    end

    def self.to_a_paginated_by_fav_adjusted_recency(limit, options = {})
      if options[:min_id].present?
        paginate_by_min_id(limit, options[:min_id], options[:max_id]).reverse
      else
        ordered_by_fav_adjusted_recency(limit, options[:max_id], options[:since_id]).to_a
      end
    end

    def self.testing_recency(limit, options = {})
      if options[:min_id].present?
        paginate_by_min_id(limit, options[:min_id], options[:max_id]).reverse
      else
        paginate_by_age_and_likes(limit, options[:max_id], options[:since_id]).to_a
      end
    end
  end
end
