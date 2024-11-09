# frozen_string_literal: true
require 'mysql2'
#require 'active_record'

#require 'dotenv'

module Paginable
  extend ActiveSupport::Concern

  included do
    scope :paginate_by_max_id, ->(limit, max_id = nil, since_id = nil) {
      Rails.logger.info "paginate_by_max_id scope called"
      query = order(arel_table[:id].desc).limit(limit)
      query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      query = query.where(arel_table[:id].gt(since_id)) if since_id.present?
      query
    }

    # Differs from :paginate_by_max_id in that it gives the results immediately following min_id,
    # whereas since_id gives the items with largest id, but with since_id as a cutoff.
    # Results will be in ascending order by id.
    scope :paginate_by_min_id, ->(limit, min_id = nil, max_id = nil) {
      Rails.logger.info "paginate_by_min_id scope called"
      query = reorder(arel_table[:id]).limit(limit)
      query = query.where(arel_table[:id].gt(min_id)) if min_id.present?
      query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      query
    }

    #my first attempt:
    scope :paginate_by_max_id_fav, ->(limit, max_id = nil, since_id = nil) {
      Rails.logger.info "paginate_by_max_id_fav scope called"
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
      Rails.logger.info "paginate_by_fav_adjusted_recency scope called"
      age_in_seconds = Arel::Nodes::NamedFunction.new('EXTRACT', [
        Arel.sql('EPOCH FROM NOW() - created_at')
      ])
      fav_adjustment = StatusStat.arel_table[:favourites_count].mul(3600)
      weighted_age = Arel::Nodes::Subtraction.new(age_in_seconds, fav_adjustment)

      query = joins(:status_stat).order(weighted_age.asc)
      query
    }

    #testing
    scope :paginate_by_ext, ->(limit, max_id = nil, since_id = nil) {
      Rails.logger.info "paginate_by_ext scope called"
      query = joins(:status_stat) #this join no longer necessary if ranking based on external table
      query = query.reorder(arel_table[:created_at].desc).limit(limit)
      query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
      query = query.where(arel_table[:id].gt(since_id)) if since_id.present?
      #Rails.logger.info "paginate_by_created_at result IDs: #{query.limit(5).pluck(:id).inspect}"
      #Rails.logger.info "paginate_by_created_at result textss: #{query.limit(5).pluck(:text).inspect}"
      client = Mysql2::Client.new(
        host: ENV['EXT_DB_HOST'],
        username: ENV['EXT_DB_USERNAME'],
        password: ENV['EXT_DB_PASSWORD'],
        database: ENV['EXT_DB_DATABASE'],
        port: ENV['EXT_DB_PORT']
      )
      # Execute a query to get data from `algo_status_scores`
      result = client.query("SELECT * FROM algo_status_scores LIMIT 5")
      #Rails.logger.info "EXTERNAL IDs: #{result.limit(5).pluck(:id).inspect}"
      #Rails.logger.info "EXTERNAL texts: #{result.limit(5).pluck(:nchar_score).inspect}"
      result.each do |row|
        Rails.logger.info "algo_status_scores row: #{row.inspect}"
      end
      #Rails.logger.info "DB_HOST is set to: #{ENV['EXT_DB_HOST']}"
      client.close
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
        paginate_by_ext(limit, options[:max_id], options[:since_id]).to_a
      end
    end
  end
end
