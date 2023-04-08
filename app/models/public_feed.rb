# frozen_string_literal: true

class PublicFeed
  # @param [Account] account
  # @param [Hash] options
  # @option [Boolean] :with_replies
  # @option [Boolean] :with_reblogs
  # @option [Boolean] :local
  # @option [Boolean] :remote
  # @option [Boolean] :only_media
  def initialize(account, options = {})
    @account = account
    @options = options
  end

  # @param [Integer] limit
  # @param [Integer] max_id
  # @param [Integer] since_id
  # @param [Integer] min_id
  # @return [Array<Status>]
  def get(limit, max_id = nil, since_id = nil, min_id = nil)
    scope = public_scope

    scope.merge!(without_replies_scope) unless with_replies?
    scope.merge!(without_reblogs_scope) unless with_reblogs?
    scope.merge!(local_only_scope) if local_only?
    scope.merge!(remote_only_scope) if remote_only?
    scope.merge!(account_filters_scope) if account?
    scope.merge!(media_only_scope) if media_only?
    scope.merge!(language_scope) if account&.chosen_languages.present?

    #scope.cache_ids.to_a_paginated_by_id(limit, max_id: max_id, since_id: since_id, min_id: min_id)#would need to write alternative method to paginate by rank
    scope.cache_ids_fav.to_a_paginated_by_id(limit, max_id: max_id, since_id: since_id, min_id: min_id) #this version should pass along fav counts in addition to ids
    #scope.cache_ids_fav.to_a_paginated_by_id_fav(limit, max_id: max_id, since_id: since_id, min_id: min_id) #this version uses my alternative pagination function
  end

  private

  attr_reader :account, :options

  def with_reblogs?
    options[:with_reblogs]
  end

  def with_replies?
    options[:with_replies]
  end

  def local_only?
    options[:local]
  end

  def remote_only?
    options[:remote]
  end

  def account?
    account.present?
  end

  def media_only?
    options[:only_media]
  end

  # def public_scope
  #   Status.with_public_visibility.joins(:account).merge(Account.without_suspended.without_silenced) #change this to look in StatusStats?
  # end

  def public_scope
    Status.with_public_visibility.joins(:account, :status_stat).merge(Account.without_suspended.without_silenced).select("statuses.*, status_stats.favourites_count")
  end

  # def public_scope
  #   Status.with_public_visibility
  #         .joins(:account, :status_stats)
  #         .merge(Account.without_suspended.without_silenced)
  #         .order("status_stats.favourites_count DESC") #depending on how cache_ids and to_a_paginated_by_id methods work, this could be useful...
  # end

  def local_only_scope
    Status.local
  end

  def remote_only_scope
    Status.remote
  end

  def without_replies_scope
    Status.without_replies
  end

  def without_reblogs_scope
    Status.without_reblogs
  end

  def media_only_scope
    Status.joins(:media_attachments).group(:id)
  end

  def language_scope
    Status.where(language: account.chosen_languages)
  end

  def account_filters_scope
    Status.not_excluded_by_account(account).tap do |scope|
      scope.merge!(Status.not_domain_blocked_by_account(account)) unless local_only?
    end
  end
end
