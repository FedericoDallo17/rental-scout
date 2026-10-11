Rails.application.routes.draw do
  get "tour", to: "tours#show", as: :tour
  get "up" => "rails/health#show", as: :rails_health_check
  get "service-worker.js", to: "service_workers#show", defaults: { format: :js }

  devise_for :users
  authenticated :user do
    root "listings#index", as: :authenticated_root
  end
  root to: redirect("/users/sign_in")
  get "notification_results", to: "notification_results#show", as: :notification_results
  resources :listings, only: [:index]
  resources :listing_tracks, only: [:index, :create, :update]
  resources :scraping_runs, only: [:index, :show]
  resources :search_preferences, except: [:index, :show]
  resource :notification_settings, only: [:edit, :update, :destroy] do
    post :test_delivery
  end
  resources :push_subscriptions, only: [:create, :destroy] do
    delete :current, on: :collection
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
