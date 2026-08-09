Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users
  authenticated :user do
    root "listings#index", as: :authenticated_root
  end
  root to: redirect("/users/sign_in")
  resources :listings, only: [:index]
  resources :scraping_runs, only: [:index, :show]
  resources :search_preferences, except: [:index, :show]
  resource :notification_settings, only: [:edit, :update, :destroy] do
    post :test_delivery
  end
  resource :language_settings, only: [:update]

  namespace :admin do
    root "scraping_runs#index"
    resources :scraping_runs, only: [:show]
    resources :listing_sources, only: [:update]
    resources :users, only: [:index, :update]
    resource :maintenance, only: [:create], controller: "maintenance"
  end
end
