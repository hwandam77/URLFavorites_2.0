Rails.application.routes.draw do
  # DSL 을 사용하여 애플리케이션 라우트를 정의합니다. https://guides.rubyonrails.org/routing.html

  # 예외 없이 부팅되면 200, 그렇지 않으면 500 을 반환하는 /up 에서 건강 상태를 공개합니다.
  # 로드 밸런서 및 가동 시간 모니터가 애플리케이션이 활성인지 확인하는 데 사용할 수 있습니다.
  get "up" => "rails/health#show", as: :rails_health_check

  # app/views/pwa/* 에서 동적 PWA 파일을 렌더링합니다 (application.html.erb 에서 manifest 를 연결하는 것을 기억하세요)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "favorites#index"

  resource :session, only: %i[new create destroy]
  resource :password, only: %i[edit update]

  resources :favorites, only: %i[index create show destroy] do
    resource :note, only: %i[update], controller: "favorite_notes"
    resource :collection_membership, only: %i[create destroy]
    patch :update_category, on: :member
    get :manual, on: :member
    get :brief, on: :member
    post :retry, on: :member
    post :reanalyze, on: :member
    post :toggle_pin, on: :member
    post :share, on: :collection
  end

  resources :collections, only: %i[index show create update destroy]
end
