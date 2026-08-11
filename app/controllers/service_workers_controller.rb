class ServiceWorkersController < ActionController::Base
  skip_forgery_protection

  def show
    response.headers["Cache-Control"] = "no-store"
    render formats: :js
  end
end
