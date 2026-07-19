module Admin
  class UsersController < BaseController
    def index
      @users = User.left_joins(:search_preferences)
        .select("users.*", "COUNT(search_preferences.id) AS search_preferences_count")
        .group("users.id")
        .order(:first_name, :last_name, :email)
        .to_a
    end

    def update
      user = User.find(params[:id])
      admin = ActiveModel::Type::Boolean.new.cast(params.require(:user).fetch(:admin))

      if user == current_user && !admin
        redirect_to admin_users_path, alert: t("admin.users.self_demote_blocked")
        return
      end

      user.update!(admin:)
      redirect_to admin_users_path, notice: t("admin.users.role_updated", email: user.email)
    end
  end
end
