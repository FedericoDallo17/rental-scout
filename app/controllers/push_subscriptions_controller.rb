class PushSubscriptionsController < ApplicationController
  def create
    subscription = current_user.push_subscriptions.find_or_initialize_by(endpoint: subscription_params[:endpoint])
    subscription.assign_attributes(
      user: current_user,
      p256dh: subscription_params.dig(:keys, :p256dh),
      auth: subscription_params.dig(:keys, :auth),
      user_agent: request.user_agent
    )
    subscription.save!

    render json: { id: subscription.id }, status: :created
  end

  def destroy
    current_user.push_subscriptions.find(params[:id]).destroy!
    head :no_content
  end

  def current
    current_user.push_subscriptions.find_by!(endpoint: params.require(:endpoint)).destroy!
    head :no_content
  end

  private

  def subscription_params
    params.require(:subscription).permit(:endpoint, keys: [:p256dh, :auth])
  end
end
