# frozen_string_literal: true
require 'mysql2'

class Feed
  include Redisable

  def initialize(type, id)
    @type = type
    @id   = id
  end

  def get(limit, max_id = nil, since_id = nil, min_id = nil)
    limit    = limit.to_i
    max_id   = max_id.to_i if max_id.present?
    since_id = since_id.to_i if since_id.present?
    min_id   = min_id.to_i if min_id.present?
    # Rails.logger.info "HELLO WORLD!!!!"
    # client = Mysql2::Client.new(#these credentials will need to be added to .env.production programmatically when creating new instances
    #     host: ENV['EXT_DB_HOST'],
    #     username: ENV['EXT_DB_USERNAME'],
    #     password: ENV['EXT_DB_PASSWORD'],
    #     database: ENV['EXT_DB_DATABASE'],
    #     port: ENV['EXT_DB_PORT']
    # )
    # # Execute a query to get data from `algo_status_scores`
    # result = client.query("SELECT * FROM algo_status_scores LIMIT 5")
    # #Rails.logger.info "EXTERNAL IDs: #{result.limit(5).pluck(:id).inspect}"
    # #Rails.logger.info "EXTERNAL texts: #{result.limit(5).pluck(:nchar_score).inspect}"
    # # log the current time
    # Rails.logger.info "Current time: #{Time.now}"
    # result.each do |row|
    #   Rails.logger.info "external scores in feed.rb row: #{row.inspect}"
    # end
    from_redis(limit, max_id, since_id, min_id)
  end

  protected

  def from_redis(limit, max_id, since_id, min_id)
    max_id = '+inf' if max_id.blank?
    if min_id.blank?
      since_id   = '-inf' if since_id.blank?
      unhydrated = redis.zrevrangebyscore(key, "(#{max_id}", "(#{since_id}", limit: [0, limit], with_scores: true).map(&:first).map(&:to_i)
    else
      unhydrated = redis.zrangebyscore(key, "(#{min_id}", "(#{max_id}", limit: [0, limit], with_scores: true).map(&:first).map(&:to_i)
    end

    Status.where(id: unhydrated).cache_ids
  end

  def key
    FeedManager.instance.key(@type, @id)
  end
end
