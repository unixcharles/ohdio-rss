Rails.application.routes.draw do
  root "feeds#index"

  resources :feeds do
    get :episodes, on: :member
    get "episodes/:episode_id/segments", to: "feeds#segments", on: :member, as: :episode_segments
  end

  get "rss/:uid", to: "rss#show", as: :rss_feed, defaults: { format: :rss }
  get "downloads/:uid/episodes/:episode_id.mp3", to: "downloads#episode_mp3", as: :episode_download_mp3

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
