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
      query = joins(:status_stat) #need to avoid dropping 0-favourite posts in this join -- need to find out how to treat "unjoined" as "0 favourites"
      #query = query.reorder(StatusStat.arel_table[:favourites_count]).limit(limit) #this worked, though it seemed to have a limited chronological window within which it drew off posts and ordered them (could not load more posts afterwards)
      #query = query.reorder(arel_table[:created_at].desc).limit(limit) # works
      query = query.reorder(StatusStat.arel_table[:favourites_count].desc).order(arel_table[:created_at].desc).limit(limit) #should order by favourites_count.desc, then by created_at.desc
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
