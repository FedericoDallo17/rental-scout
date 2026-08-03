Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users
  root "listings#index"
  resources :listings, only: [:index]
  resources :scraping_runs, only: [:index, :show]
  resources :search_preferences, except: [:index, :show]
  resource :notification_settings, only: [:edit, :update, :destroy]
  resource :language_settings, only: [:update]

  namespace :admin do
    root "scraping_runs#index"
    resources :scraping_runs, only: [:show]
    resources :listing_sources, only: [:update]
    resources :users, only: [:index, :update]
    resource :maintenance, only: [:create], controller: "maintenance"
  end
end
