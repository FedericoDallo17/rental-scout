Rails.application.routes.draw do
  root "listings#index"
  resources :listings, only: [:index]
end
