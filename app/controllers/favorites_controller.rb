class FavoritesController < ApplicationController
  def index
    @favorites = UrlFavorites::UseCases::Search::FavoriteSearch.call(
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

    if url.blank?
      return render_url_error("URL을 입력해주세요.")
    end

    normalized = begin
      UrlFavorites::Domain::Urls::Normalizer.call(url)
    rescue URI::InvalidURIError, ArgumentError
      return render_url_error("잘못된 URL 주소입니다. 확인 후 다시 입력해주세요.")
    end

    unless UrlFavorites::Domain::Urls::SafetyPolicy.allowed?(normalized)
      return render_url_error("접근할 수 없는 URL입니다.")
    end

    content_type = UrlFavorites::Domain::Urls::TypeDetector.call(normalized)
    @favorite = Favorite.new(
      url: normalized,
      title: normalized,
      content_type: content_type,
      status: "analyzing"
    )

    if @favorite.save
      UrlFavorites::UseCases::Analysis::EnqueueAnalysis.call(favorite_id: @favorite.id)

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to favorites_url, notice: "URL이 저장되었습니다. 분석을 시작합니다." }
      end
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
    UrlFavorites::Integrations::Search::Indexer.remove(@favorite.id)
    @favorite.destroy
    redirect_to favorites_url, notice: "Deleted"
  end

  def retry
    @favorite = Favorite.find(params[:id])
    @favorite.update!(status: "pending")
    UrlFavorites::UseCases::Analysis::EnqueueAnalysis.call(favorite_id: @favorite.id)
    redirect_to favorite_url(@favorite), notice: "Retrying analysis"
  end

  def toggle_pin
    @favorite = Favorite.find(params[:id])
    @favorite.update!(pinned: !@favorite.pinned)
    redirect_back_or_to favorites_url, notice: @favorite.pinned? ? "북마크가 핀되었습니다" : "핀 해제되었습니다"
  end

  def update_category
    @favorite = Favorite.find(params[:id])
    @favorite.update!(category: params[:category])

    respond_to do |format|
      format.turbo_stream do
        partial = params[:view_mode] == "list" ? "favorites/favorite_row" : "favorites/favorite_card"
        render turbo_stream: turbo_stream.replace(
          @favorite,
          partial: partial,
          locals: { favorite: @favorite }
        )
      end
      format.json { render json: { category: @favorite.category } }
      format.html { redirect_to favorites_url }
    end
  end

  private

  def render_url_error(message)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("url-error", build_error_html(message))
      end
      format.html { redirect_to favorites_url, alert: message }
    end
  end

  def build_error_html(message)
    <<~HTML
      <div class="mb-4 p-3 rounded-lg flex items-center gap-2" style="background:var(--color-failed-bg);border:1px solid var(--color-failed-border);">
        <svg class="w-4 h-4 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2" style="color:var(--color-failed-text);">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 11-18 0 9 9 0 0118 0zm-9 3.75h.008v.008H12v-.008z"/>
        </svg>
        <span style="font-size:var(--text-sm);font-weight:500;color:var(--color-failed-text);">#{ERB::Util.html_escape(message)}</span>
      </div>
    HTML
  end
end
