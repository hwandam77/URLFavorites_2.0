class FavoritesController < ApplicationController
  def index
    @favorites = FavoriteSearch.call(
      query: params[:q],
      content_type: params[:content_type],
      status: params[:status],
      collection_id: params[:collection_id],
      sort: params[:sort] || "recent",
      category: params[:category]
    )
    @view_mode = params[:view_mode] || "card"
  end

  def show
    @favorite = Favorite.find(params[:id])
  end

  def create
    url = params.dig(:favorite, :url).to_s.strip
    normalized = UrlFavorites::Domain::Urls::Normalizer.call(url)

    unless UrlFavorites::Domain::Urls::SafetyPolicy.allowed?(normalized)
      redirect_to favorites_url, alert: "Unsafe URL"
      return
    end

    content_type = UrlFavorites::Domain::Urls::TypeDetector.call(normalized)
    @favorite = Favorite.new(
      url: normalized,
      title: normalized,
      content_type: content_type,
      status: "pending"
    )

    if @favorite.save
      if content_type == "youtube"
        AnalyzeYoutubeJob.perform_later(@favorite.id)
      else
        AnalyzeWebpageJob.perform_later(@favorite.id)
      end
      redirect_to favorites_url, notice: "URL이 저장되었습니다. 분석을 시작합니다."
    else
      if Favorite.exists?(url: normalized)
        existing = Favorite.find_by(url: normalized)
        redirect_to favorite_url(existing), alert: "이미 등록된 URL입니다. 기존 북마크로 이동합니다."
      else
        redirect_to favorites_url, alert: "저장에 실패했습니다. 다시 시도해주세요."
      end
    end
  end

  def destroy
    @favorite = Favorite.find(params[:id])
    FavoriteSearchIndexer.remove(@favorite.id)
    @favorite.destroy
    redirect_to favorites_url, notice: "Deleted"
  end

  def retry
    @favorite = Favorite.find(params[:id])
    @favorite.update!(status: "pending")
    if @favorite.content_type == "youtube"
      AnalyzeYoutubeJob.perform_later(@favorite.id)
    else
      AnalyzeWebpageJob.perform_later(@favorite.id)
    end
    redirect_to favorite_url(@favorite), notice: "Retrying analysis"
  end

  def toggle_pin
    @favorite = Favorite.find(params[:id])
    @favorite.update!(pinned: !@favorite.pinned)
    redirect_back_or_to favorites_url, notice: @favorite.pinned? ? "북마크가 핀されました" : "핀 해제되었습니다"
  end
end
