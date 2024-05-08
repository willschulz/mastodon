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

    #my first attempt:
    scope :paginate_by_max_id_fav, ->(limit, max_id = nil, since_id = nil) {
      query = joins(:status_stat)
              .reorder((Arel::Nodes::Multiplication.new(StatusStat.arel_table[:favourites_count], 100000000000) + Arel::Nodes::BitwiseShiftRight.new(arel_table[:id],22)).desc) #good but bitshift not working as intended
              .limit(20)
      query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      query = query.where(arel_table[:id].gt(since_id)) if since_id.present?
      query = query
      query
    }

    #gpt suggestion that broke public feed, either because bad code or because favs not cached.  going to walk back and try to make working reverse-chrono from created_at...
    scope :ordered_by_fav_adjusted_recency, -> {
      age_in_seconds = Arel::Nodes::NamedFunction.new('EXTRACT', [
        Arel.sql('EPOCH FROM NOW() - created_at')
      ])
      fav_adjustment = StatusStat.arel_table[:favourites_count].mul(3600)
      weighted_age = Arel::Nodes::Subtraction.new(age_in_seconds, fav_adjustment)

      query = joins(:status_stat).order(weighted_age.asc)
      query
    }

    #testing recency + some function of fav.count
    scope :paginate_by_created_at, ->(limit, max_id = nil, since_id = nil) {
      #recency_with_favourites = Arel.sql("EXTRACT(EPOCH FROM now() - created_at) - (status_stats.favourites_count * 3600)") #this might have broken something
      query = left_joins(:status_stat) #trying to avoid dropping 0-favourite posts in this join
      #query = query.reorder(StatusStat.arel_table[:favourites_count]).limit(limit) #this worked, though it seemed to have a limited chronological window within which it drew off posts and ordered them (could not load more posts afterwards)
      #query = query.reorder(arel_table[:created_at].desc).limit(limit) # works
      #query = query.reorder(StatusStat.arel_table[:favourites_count].desc).order(arel_table[:created_at].desc).limit(limit) #works, but 0-fav posts are at the top, which isn't what I wanted (and sti
      #ordering = "COALESCE(status_stat.favourites_count, 0) DESC, created_at DESC" # This GPT suggestion broke things: Use COALESCE to default favourites_count to 0 if it is NULL, and implement rest of logic here
      #query = query.order(Arel.sql(ordering)).limit(limit)
      # Create an Arel node to handle nulls in favourites_count
      coalesced_favourites_count = Arel::Nodes::NamedFunction.new('COALESCE', [ #
        StatusStat.arel_table[:favourites_count], Arel::Nodes.build_quoted(0)
      ])

      weighted_favourites_count = Arel::Nodes::Multiplication.new(coalesced_favourites_count, 3600)

      # Hardcode the created_at timestamp of the newest post for debugging
      #hardcoded_newest_post_created_at = Arel::Nodes.build_quoted(DateTime.new(2024, 5, 9, 12, 0, 0))
      current_time = Arel::Nodes.build_quoted(DateTime.now)

      # Extract created_at into a variable
      created_at_column = arel_table[:created_at]

      # Calculate the difference in seconds between hardcoded newest post created_at and each post's created_at
      age_in_seconds = Arel::Nodes::Subtraction.new(
        current_time, 
        created_at_column
      )

      # Cast difference_in_seconds to numeric
      #numeric_age_in_seconds = Arel::Nodes::NamedFunction.new('CAST', [
      #  Arel::Nodes::As.new(age_in_seconds, Arel::Nodes::SqlLiteral.new('numeric'))
      #])

      # todo: try casting with Arel (no SqlLiteral)
      numeric_age_in_seconds = Arel::Nodes::NamedFunction.new('CAST', [
        Arel::Nodes::As.new(age_in_seconds, Arel::Nodes.build_quoted('numeric'))
      ])

      # Calculate the weighted score
      weighted_score = Arel::Nodes::Subtraction.new(
        numeric_age_in_seconds,
        weighted_favourites_count
      )

      # todo: try adding min(weighted_score) to weighted_score in case negative numbers are the problem...

      # Order by the weighted score
      query = query.reorder(numeric_age_in_seconds.asc).limit(limit)

      # Order by the age in seconds
      #query = query.reorder(coalesced_favourites_count.desc)
      #query = query.order(age_in_seconds.asc).limit(limit)
      
      query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      query = query.where(arel_table[:id].gt(since_id)) if since_id.present?
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
        paginate_by_created_at(limit, options[:max_id], options[:since_id]).to_a
      end
    end
  end
end
