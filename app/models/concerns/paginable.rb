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

    # #New scope that connects to external table
    # scope :paginate_by_ext, ->(limit, max_id = nil, since_id = nil) {
    #   Rails.logger.info "paginate_by_ext scope called"
    #   query = joins(:status_stat) #this join no longer necessary if ranking based on external table
    #   query = query.reorder(arel_table[:created_at].desc).limit(limit)
    #   query = query.where(arel_table[:id].lt(max_id)) if max_id.present?
    #   query = query.where(arel_table[:id].gt(since_id)) if since_id.present?
    #   #Rails.logger.info "paginate_by_created_at result IDs: #{query.limit(5).pluck(:id).inspect}"
    #   #Rails.logger.info "paginate_by_created_at result textss: #{query.limit(5).pluck(:text).inspect}"
    #   client = Mysql2::Client.new(#these credentials will need to be added to .env.production programmatically when creating new instances
    #     host: ENV['EXT_DB_HOST'],
    #     username: ENV['EXT_DB_USERNAME'],
    #     password: ENV['EXT_DB_PASSWORD'],
    #     database: ENV['EXT_DB_DATABASE'],
    #     port: ENV['EXT_DB_PORT']
    #   )
    #   # Execute a query to get data from `algo_status_scores`
    #   result = client.query("SELECT * FROM algo_status_scores LIMIT 5")
    #   #Rails.logger.info "EXTERNAL IDs: #{result.limit(5).pluck(:id).inspect}"
    #   #Rails.logger.info "EXTERNAL texts: #{result.limit(5).pluck(:nchar_score).inspect}"
    #   result.each do |row|
    #     Rails.logger.info "algo_status_scores row: #{row.inspect}"
    #   end
    #   #Rails.logger.info "DB_HOST is set to: #{ENV['EXT_DB_HOST']}"
    #   client.close
    #   query
    # }

    def self.to_a_paginated_by_id(limit, options = {})
      if options[:min_id].present?
        paginate_by_min_id(limit, options[:min_id], options[:max_id]).reverse
      else
        paginate_by_max_id(limit, options[:max_id], options[:since_id]).to_a
      end
    end

    def self.testing_ext_db_conn(limit, options = {})
      if options[:min_id].present?
        paginate_by_min_id(limit, options[:min_id], options[:max_id]).reverse
      else
        paginate_by_ext(limit, options[:max_id], options[:since_id]).to_a
      end
    end
  end
end
