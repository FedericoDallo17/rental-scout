Rails.application.routes.draw do
  devise_for :users
  root "listings#index"
  resources :listings, only: [:index]
  resources :scraping_runs, only: [:index, :show]
  resources :search_preferences, except: [:index, :show]
  resource :notification_settings, only: [:edit, :update, :destroy]
  resource :language_settings, only: [:update]

  namespace :admin do
    root "scraping_runs#index"
    resources :listing_sources, only: [:update]
    resources :users, only: [:index, :update]
    resource :maintenance, only: [:create], controller: "maintenance"
  end
end
