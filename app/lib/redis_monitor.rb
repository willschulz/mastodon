# frozen_string_literal: true

require 'singleton'

class RedisMonitor
  include Singleton
  include Redisable

  MEMORY_THRESHOLD = 100_000_000 # 100MB
  SLOW_QUERY_THRESHOLD = 1.0 # 1 second
  CACHE_TTL = 5.minutes
  MAX_CACHE_SIZE = 1000

  def initialize
    @operation_stats = {}
    @memory_usage_cache = {}
    @slow_queries = []
    @cache_hits = 0
    @cache_misses = 0
  end

  def monitor_operation(operation_name, options = {})
    start_time = Time.now
    memory_before = get_redis_memory_usage
    result = yield(redis)
    duration = Time.now - start_time
    memory_after = get_redis_memory_usage
    memory_delta = memory_after - memory_before
    @operation_stats[operation_name] ||= { count: 0, total_duration: 0, total_memory: 0 }
    @operation_stats[operation_name][:count] += 1
    @operation_stats[operation_name][:total_duration] += duration
    @operation_stats[operation_name][:total_memory] += memory_delta
    if duration > SLOW_QUERY_THRESHOLD
      @slow_queries << { op: operation_name, duration: duration, memory: memory_delta, time: Time.now }
      @slow_queries = @slow_queries.last(20)
    end
    result
  end

  def monitored_zrange(key, start, stop, options = {})
    cache_key = "zrange:#{key}:#{start}:#{stop}:#{options.hash}"
    if @memory_usage_cache.key?(cache_key)
      @cache_hits += 1
      return @memory_usage_cache[cache_key][:result]
    end
    @cache_misses += 1
    result = monitor_operation('zrange', key: key, start: start, stop: stop, options: options) do |r|
      r.zrange(key, start, stop, options)
    end
    @memory_usage_cache[cache_key] = { result: result, time: Time.now }
    @memory_usage_cache.shift if @memory_usage_cache.size > MAX_CACHE_SIZE
    result
  end

  def get_stats
    {
      operation_stats: @operation_stats,
      slow_queries: @slow_queries.last(10),
      cache_stats: {
        hits: @cache_hits,
        misses: @cache_misses,
        hit_rate: @cache_hits.to_f / ((@cache_hits + @cache_misses).nonzero? || 1) * 100
      },
      memory_usage: get_redis_memory_usage,
      memory_usage_cache: @memory_usage_cache
    }
  end

  def clear_stats
    @operation_stats.clear
    @slow_queries.clear
    @cache_hits = 0
    @cache_misses = 0
    @memory_usage_cache.clear
  end

  def get_redis_memory_usage
    redis.info['used_memory'].to_i
  end

  def problematic_key?(key)
    redis.memory('usage', key) > MEMORY_THRESHOLD rescue false
  end

  def get_key_memory_usage(key)
    redis.memory('usage', key) rescue 0
  end
end 