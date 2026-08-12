class ApplicationController < ActionController::Base
  include Authentication

  # 최신 브라우저만 허용 (webp 이미지, 웹 푸시, 배지, import maps, CSS nesting, CSS :has 지원)
  allow_browser versions: :modern

  # importmap 변경 시 HTML 응답의 etag가 무효화됨
  stale_when_importmap_changes

  before_action :set_sidebar_data

  private

  def set_sidebar_data
    @collections = Rails.cache.fetch('sidebar_collections', expires_in: 10.minutes) do
      Collection.order(:name).to_a
    end
  end
end
