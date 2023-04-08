# frozen_string_literal: true

# need to make a new version of this file that paginates by rank, or else find a way to use the same function to paginate by rank

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
      query = reorder(arel_table[:id]).limit(limit) #can I reorder by weighted_id instead and get the desired result?
      query = query.where(arel_table[:id].gt(min_id)) if min_id.present?
      query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      query
    }

    #my attempt:
    scope :paginate_by_max_id_fav ->(limit, max_id = nil, since_id = nil) {
      query = order(arel_table[:id].desc).limit(limit)
      query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      query = query.where(arel_table[:id].gt(since_id)) if since_id.present?
      query
    }

    scope :paginate_by_min_id_fav, ->(limit, min_id = nil, max_id = nil) {
      query = reorder(arel_table[:id]).limit(limit) #can I reorder by weighted_id instead and get the desired result?
      query = query.where(arel_table[:id].gt(min_id)) if min_id.present?
      query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      query
    }

    def self.to_a_paginated_by_id(limit, options = {})
      if options[:min_id].present?
        paginate_by_min_id(limit, options[:min_id], options[:max_id]).reverse
      else
        paginate_by_max_id(limit, options[:max_id], options[:since_id]).to_a
      end
    end

    def self.to_a_paginated_by_id_fav(limit, options = {})
      if options[:min_id].present?
        paginate_by_min_id_fav(limit, options[:min_id], options[:max_id]).reverse
      else
        paginate_by_max_id_fav(limit, options[:max_id], options[:since_id]).to_a
      end
    end
  end
end
