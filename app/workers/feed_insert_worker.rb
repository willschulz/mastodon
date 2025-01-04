# frozen_string_literal: true

# require 'net/http'
# require 'uri'
# require 'json'


class FeedInsertWorker
  include Sidekiq::Worker

  def perform(status_id, id, type = 'home', options = {})
    @type      = type.to_sym
    @status    = Status.find(status_id)
    @options   = options.symbolize_keys

    # #Rails.logger.info "Test log: FeedInsertWorker: status_id: #{status_id}, id: #{id}, type: #{type}, options: #{options}"

    # ##Rails.logger.info "Current status text is #{@status.text}"

    # # Define the URL and request data
    # url = URI.parse("http://192.81.218.82:3005/get-score")
    # http = Net::HTTP.new(url.host, url.port)

    # # Prepare the request
    # request_text = url.path + "?status_id=#{status_id.to_s}&id=#{id.to_s}"
    # Rails.logger.info "FeedInsertWorker canary request_text is #{request_text}"
    # request = Net::HTTP::Get.new(request_text)

    # # Send the request
    # response = http.request(request)

    # # Print the response
    # puts response.body

    # # extract the score from the response
    # score = JSON.parse(response.body)["score"]
    # puts "FeedInsertWorker canary score is #{score}"

    # looks like this runs for every person (id) who is relevant (follows, is mentioned, etc) to the status
    # so, we need to add a call to an api endpoint on the scoring machine to send the status text (and eventually also any media content) along with the relevant user id, and get back the appropriate score/rank for the status-user pair

    #additionally, we need to pas sthe score/rank down to the rest of this process

    case @type
    when :home, :tags
      @follower = Account.find(id)
    when :list
      @list     = List.find(id)
      @follower = @list.account
    end

    check_and_insert
  rescue ActiveRecord::RecordNotFound
    true
  end

  private

  def check_and_insert
    if feed_filtered?
      perform_unpush if update?
    else
      perform_push
      perform_notify if notify?
    end
  end

  def feed_filtered?
    case @type
    when :home
      FeedManager.instance.filter?(:home, @status, @follower)
    when :tags
      FeedManager.instance.filter?(:tags, @status, @follower)
    when :list
      FeedManager.instance.filter?(:list, @status, @list)
    end
  end

  def notify?
    return false if @type != :home || @status.reblog? || (@status.reply? && @status.in_reply_to_account_id != @status.account_id)

    Follow.find_by(account: @follower, target_account: @status.account)&.notify?
  end

  def perform_push
    case @type
    when :home, :tags
      FeedManager.instance.push_to_home(@follower, @status, update: update?)
    when :list
      FeedManager.instance.push_to_list(@list, @status, update: update?)
    end
  end

  def perform_unpush
    case @type
    when :home, :tags
      FeedManager.instance.unpush_from_home(@follower, @status, update: true)
    when :list
      FeedManager.instance.unpush_from_list(@list, @status, update: true)
    end
  end

  def perform_notify
    LocalNotificationWorker.perform_async(@follower.id, @status.id, 'Status', 'status')
  end

  def update?
    @options[:update]
  end
end
