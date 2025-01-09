# to do: modify this to fix pagination
# frozen_string_literal: true

class HomeFeed < Feed
  def initialize(account)
    @account = account
    super(:home, account.id)
  end

  def regenerating?
    redis.exists?("account:#{@account.id}:regeneration")
  end

  def get(limit, max_id = nil, since_id = nil, min_id = nil)
    limit    = limit.to_i
    max_id   = max_id.to_i if max_id.present?
    since_id = since_id.to_i if since_id.present?
    min_id   = min_id.to_i if min_id.present?

    from_redis_withscores(limit, max_id, since_id, min_id)
  end

  def from_redis_withscores(limit, max_id, since_id, min_id)
    if min_id == '-inf'
      unhydrated_with_scores = redis.zrevrangebyscore(key, "(#{max_id}", "(#{since_id}", limit: [0, limit], with_scores: true)
    else
      unhydrated_with_scores = redis.zrangebyscore(key, "(#{min_id}", "(#{max_id}", limit: [0, limit], with_scores: true)
    end
  
    # Create a map of ID to score
    score_map = unhydrated_with_scores.to_h
  
    # Fetch statuses and include scores
    Status.where(id: score_map.keys.map(&:to_i)).cache_ids.map do |status|
      status.define_singleton_method(:score) { score_map[status.id.to_s] }
      status
    end.sort_by { |status| -status.score }
  end
  

  def from_redis(limit, max_id, since_id, min_id)
    max_id = '+inf' if max_id.blank?
    if min_id.blank?
      since_id   = '-inf' if since_id.blank?
      unhydrated = redis.zrevrangebyscore(key, "(#{max_id}", "(#{since_id}", limit: [0, limit], with_scores: true).map(&:first).map(&:to_i)
    else
      unhydrated = redis.zrangebyscore(key, "(#{min_id}", "(#{max_id}", limit: [0, limit], with_scores: true).map(&:first).map(&:to_i)
    end
    # Rails.logger.info("from_redis unhydrated #{unhydrated}")
    unhydrated_with_scores = redis.zrevrangebyscore(key, '+inf', '-inf', limit: [0, limit], with_scores: true)
    u_map = unhydrated_with_scores.to_h
    # Rails.logger.info("from_redis unhydrated #{u_map}")

    unhydrated = unhydrated_with_scores.map(&:first).map(&:to_i)

    # Rails.logger.info("from_redis unhydrated #{Status.where(id: unhydrated).cache_ids}")
    # Rails.logger.info("from_redis unhydrated #{ Status.where(id: unhydrated).cache_ids.sort_by { |status| u_map[status.id.to_s] }}")

    Status.where(id: unhydrated).cache_ids.sort_by { |status| -u_map[status.id.to_s] }
  end
end
