Rails.application.routes.draw do
  devise_for :users
  root "listings#index"
  resources :listings, only: [:index]
  resources :search_preferences, except: [:index, :show]
  resources :scraping_runs, only: [:index]
end
