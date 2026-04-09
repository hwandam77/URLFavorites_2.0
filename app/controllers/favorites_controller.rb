class FavoritesController < ApplicationController
  def index
    @favorites = FavoriteSearch.call(
      query: params[:q],
      content_type: params[:content_type],
      status: params[:status],
      collection_id: params[:collection_id],
      sort: params[:sort] || "recent"
    )
    @view_mode = params[:view_mode] || "card"
  end

  def show
    @favorite = Favorite.find(params[:id])
  end

  def create
    url = params.dig(:favorite, :url).to_s.strip
    normalized = UrlNormalizer.call(url)

    unless UrlSafetyValidator.call(normalized)
      redirect_to favorites_url, alert: "Unsafe URL"
      return
    end

    content_type = UrlTypeDetector.call(normalized)
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
      redirect_to favorites_url, notice: "URL saved"
    else
      redirect_to favorites_url, alert: "Failed to save"
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
end
