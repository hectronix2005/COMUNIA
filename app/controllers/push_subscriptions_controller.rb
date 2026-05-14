class PushSubscriptionsController < ApplicationController
  def create
    sub = current_user.push_subscriptions.find_or_initialize_by(endpoint: params[:endpoint])
    sub.p256dh     = params.require(:p256dh)
    sub.auth       = params.require(:auth)
    sub.user_agent = request.user_agent
    sub.save!
    head :created
  end

  def destroy
    current_user.push_subscriptions.where(endpoint: params[:endpoint]).destroy_all
    head :ok
  end

  def vapid_key
    render json: { vapid_public_key: Rails.application.config.x.vapid[:public_key] }
  end
end
