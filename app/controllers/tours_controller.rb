class ToursController < ApplicationController
  skip_before_action :authenticate_user!, only: :show
  layout "tour"

  def show
    # Deliberately independent of inventory, user records, and background jobs.
    @examples = [
      { key: "pocitos", neighborhood: "Pocitos", price: 28000, area: 48, source: "InfoCasas" },
      { key: "buceo", neighborhood: "Buceo", price: 32000, area: 55, source: "Remax" },
      { key: "cordon", neighborhood: "Cordón", price: 38000, area: 62, source: "Imperium" }
    ]
  end
end
