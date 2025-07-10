# Ensure RedisMonitor is loaded early, for Sidekiq & web
require Rails.root.join('app/lib/redis_monitor') 