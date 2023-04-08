# frozen_string_literal: true

module Cacheable
  extend ActiveSupport::Concern

  module ClassMethods
    @cache_associated = []

    def cache_associated(*associations)
      @cache_associated = associations
    end

    def with_includes
      includes(@cache_associated)
    end

    def cache_ids
      select(:id, :updated_at)
    end

    # def cache_ids_weighted
    #   select(:id, :id_weighted, :updated_at) #could be useful if I can create a weighted_id column that is part of public_scope.  probably need to get updated_at from status_stats for this to work properly
    # end
  end
end
