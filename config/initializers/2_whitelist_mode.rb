# frozen_string_literal: true

Rails.application.configure do
  #config.x.whitelist_mode = (ENV['LIMITED_FEDERATION_MODE'] || ENV['WHITELIST_MODE']) == 'true'
  
  
  # Hard-code limited federation mode to disable all federation
  config.x.whitelist_mode = true
end
