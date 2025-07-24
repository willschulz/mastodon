# frozen_string_literal: true

class HomeController < ApplicationController
  include WebAppControllerConcern

  before_action :set_instance_presenter
  # In mastodon/app/controllers/home_controller.rb
  before_action :require_user!, if: :public_timeline_route?

  def index
    expires_in 0, public: true unless user_signed_in?
  end

  private

  def set_instance_presenter
    @instance_presenter = InstancePresenter.new
  end

  def public_timeline_route?
    # Require authentication for public timeline routes
    request.path.start_with?('/public') && !Setting.timeline_preview
  end
end
