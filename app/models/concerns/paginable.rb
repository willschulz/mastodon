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
    scope :paginate_by_max_id_fav, ->(limit, max_id = nil, since_id = nil) {
      #query = joins(:status_stat).where(StatusStat.arel_table[:favourites_count].eq(2)).order(StatusStat.arel_table[:favourites_count].desc, arel_table[:id].desc).limit(3)#this is where we go back #remember to add back  after [:id]
      #query = joins(:status_stat).order(StatusStat.arel_table[:favourites_count].desc, arel_table[:id].desc).limit(10)
      #
      #query = joins(:status_stat).where(StatusStat.arel_table[:favourites_count].in(10..21)).order(StatusStat.arel_table[:favourites_count].desc, arel_table[:id].desc).limit(6)
      # query = joins(:status_stat).reorder(arel_table[:id].desc).limit(6)
      # query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      # query = query.where(arel_table[:id].gt(since_id)) if since_id.present?
      #query = query.reorder(StatusStat.arel_table[:favourites_count].desc)
      
      # query = joins(:status_stat)
      # query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      # query = query.where(arel_table[:id].gt(since_id)) if since_id.present?
      # query = query.reorder(StatusStat.arel_table[:favourites_count].desc, arel_table[:id].desc).limit(6)

      # query = joins(:status_stat).order(arel_table[:id].desc).limit(6).reorder(StatusStat.arel_table[:favourites_count].desc)
      # query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      # query = query.where(arel_table[:id].gt(since_id)) if since_id.present?
      # query

      #query = joins(:status_stat).where(StatusStat.arel_table[:favourites_count].in(0..9)).order(arel_table[:id].desc)

      # query = joins(:status_stat)
      #       .where(StatusStat.arel_table[:favourites_count].in(10..50))
      #       .order(Arel::Nodes::NamedFunction.new('concat', [StatusStat.arel_table[:favourites_count], arel_table[:id]]).desc).limit(5)


      #query = joins(:status_stat).where(StatusStat.arel_table[:favourites_count].in(0..9))
      #.order(arel_table[:id].desc).limit(6).reorder(StatusStat.arel_table[:favourites_count].desc)      

      query = joins(:status_stat)
              .where(StatusStat.arel_table[:favourites_count].in(10..70))
              #.reorder(Arel::Nodes::NamedFunction.new('concat', [StatusStat.arel_table[:favourites_count], arel_table[:id]]).desc)
              .reorder(Arel::Nodes::NamedFunction.new('sum', [StatusStat.arel_table[:favourites_count], arel_table[:id]]).desc)
              #.reorder(Arel::Nodes::Addition.new([StatusStat.arel_table[:favourites_count], arel_table[:id]]).desc)
              #.reorder(StatusStat.arel_table[:favourites_count].desc + arel_table[:id].desc)
              .limit(20)
      query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      query = query.where(arel_table[:id].gt(since_id)) if since_id.present?
      query = query
      query
    }

    scope :paginate_by_min_id_fav, ->(limit, min_id = nil, max_id = nil) {
      # query = reorder(arel_table[:id]).limit(limit)
      # query = query.where(arel_table[:id].gt(min_id)) if min_id.present?
      # query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      # query
      query = joins(:status_stat).order(StatusStat.arel_table[:favourites_count], arel_table[:id]).limit(2)
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
