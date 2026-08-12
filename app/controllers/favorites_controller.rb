class FavoritesController < ApplicationController
  # PWA 공유 대상 POST는 CSRF 토큰이 없으므로 해당 액션만 인증 건너뜀
  skip_before_action :verify_authenticity_token, only: :share

  def index
    @favorites = UrlFavorites::UseCases::Search::FavoriteSearch.call(
      query: params[:q],
      content_type: params[:content_type],
      status: params[:status],
      collection_id: params[:collection_id],
      sort: params[:sort] || "recent",
      category: params[:category]
    )
    @view_mode = params[:view_mode] == "list" ? "list" : "card"
    @category_counts = category_counts_for_sidebar
  end

  def category_counts_for_sidebar
    counts = Favorite.where(status: "done").group(:category).count
    # 0개 카테고리 제외, 알파벳 순
    counts.select { |_k, v| v > 0 }.sort.to_h
  end

  def show
    @favorite = Favorite.find(params[:id])
  end

  # GET /favorites/:id/manual — 온보딩 매뉴얼 전용 페이지
  def manual
    @favorite = Favorite.find(params[:id])
    @analysis = @favorite.analysis
    @sections = @analysis&.analysis_sections || []

    if @sections.empty?
      redirect_to favorite_url(@favorite), alert: "생성된 매뉴얼이 없습니다."
    end
  end

  # GET /favorites/:id/brief — 뉴스레터 레이아웃 프리뷰 (manual 비교용)
  def brief
    @favorite = Favorite.find(params[:id])
    @analysis = @favorite.analysis
    @sections = @analysis&.analysis_sections&.to_a || []

    redirect_to favorite_url(@favorite), alert: "아직 분석 결과가 없습니다." if @analysis.nil?
  end

  def create
    url = params.dig(:favorite, :url).to_s.strip

    if url.blank?
      return render_url_error("URL을 입력해주세요.")
    end

    result = begin
      UrlFavorites::UseCases::Favorites::CreateFavorite.call(url: url)
    rescue URI::InvalidURIError, ArgumentError
      return render_url_error("잘못된 URL 주소입니다. 확인 후 다시 입력해주세요.")
    rescue UrlFavorites::Domain::Errors::UnsafeUrl
      return render_url_error("접근할 수 없는 URL입니다.")
    end

    @favorite = result.value[:favorite]

    if result.value[:created]
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to favorites_url, notice: "URL이 저장되었습니다. 분석을 시작합니다." }
      end
    else
      redirect_to favorite_url(@favorite), alert: "이미 등록된 URL입니다. 기존 북마크로 이동합니다."
    end
  end

  # PWA 공유 대상 — POST /favorites/share
  # 모바일 브라우저 공유 시트에서 호출됨. CSRF 보호 없이 URL을 받아 저장.
  def share
    url = params.dig(:favorite, :url).to_s.strip

    # 일부 브라우저는 URL을 text 필드에 담아 보냄
    if url.blank?
      text = params.dig(:favorite, :text).to_s.strip
      url = text if text.match?(/\Ahttps?:\/\//)
    end

    if url.blank?
      redirect_to favorites_url, alert: "공유된 URL을 찾을 수 없습니다."
      return
    end

    result = begin
      UrlFavorites::UseCases::Favorites::CreateFavorite.call(url: url)
    rescue URI::InvalidURIError, ArgumentError
      redirect_to favorites_url, alert: "잘못된 URL 주소입니다."
      return
    rescue UrlFavorites::Domain::Errors::UnsafeUrl
      redirect_to favorites_url, alert: "접근할 수 없는 URL입니다."
      return
    end

    @favorite = result.value[:favorite]

    if result.value[:created]
      redirect_to favorite_url(@favorite), notice: "URL이 저장되었습니다. 분석을 시작합니다."
    else
      redirect_to favorite_url(@favorite), alert: "이미 등록된 URL입니다."
    end
  end

  def destroy
    UrlFavorites::UseCases::Favorites::DeleteFavorite.call(id: params[:id])
    redirect_to favorites_url, notice: "Deleted"
  end

  def retry
    @favorite = UrlFavorites::UseCases::Favorites::RetryAnalysis.call(id: params[:id])
    redirect_to favorite_url(@favorite), notice: "Retrying analysis"
  end

  def reanalyze
    @favorite = UrlFavorites::UseCases::Favorites::RetryAnalysis.call(
      id: params[:id],
      analysis_style: params[:analysis_style]
    )
    redirect_to favorite_url(@favorite), notice: "분석을 다시 시작했습니다."
  end

  def toggle_pin
    @favorite = UrlFavorites::UseCases::Favorites::TogglePin.call(id: params[:id])
    redirect_back_or_to favorites_url, notice: @favorite.pinned? ? "북마크가 핀되었습니다" : "핀 해제되었습니다"
  end

  def update_category
    @favorite = UrlFavorites::UseCases::Favorites::UpdateCategory.call(
      id: params[:id],
      category: params[:category]
    )

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
