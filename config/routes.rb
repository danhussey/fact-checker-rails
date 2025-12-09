Rails.application.routes.draw do
  root "home#index"

  resources :listening_sessions, only: [:create, :show] do
    member do
      post :toggle_recording
    end
  end

  get "privacy", to: "pages#privacy"

  # Dev data export (token-protected)
  namespace :dev do
    resources :sessions, only: [:index, :show] do
      member do
        get :download
      end
    end
  end

  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # PWA
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
