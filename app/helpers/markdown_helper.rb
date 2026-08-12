# LLM이 생성한 markdown 본문을 HTML로 렌더링한다.
# LLM 출력은 신뢰 경계 밖 텍스트이므로 반드시 sanitize를 통과시킨다.
module MarkdownHelper
  RENDERER = Redcarpet::Markdown.new(
    Redcarpet::Render::HTML.new(filter_html: false),
    fenced_code_blocks: true,
    tables: true,
    autolink: true,
    strikethrough: true,
    no_intra_emphasis: true
  ).freeze

  ALLOWED_TAGS = %w[
    h1 h2 h3 h4 p ul ol li blockquote strong em code pre a
    table thead tbody tr th td hr br
  ].freeze
  ALLOWED_ATTRIBUTES = %w[href target rel class].freeze

  GITHUB_URL_RE = %r{https?://github\.com/[^/\s]+/[^/\s]+(?::[^\s]*)?/?}

  def markdown(text, link_github_favorites: true)
    return "".html_safe if text.blank?

    html = RENDERER.render(text.to_s)

    # GitHub 링크를 분석 페이지 링크로 변환
    if link_github_favorites
      html = linkify_github_favorites(html)
    end

    sanitize(
      html,
      tags: ALLOWED_TAGS,
      attributes: ALLOWED_ATTRIBUTES
    )
  end

  def linkify_github_favorites(text)
    return text unless text.is_a?(String) && text.include?("github.com")

    # Redcarpet autolink가 이미 <a href="URL">URL</a> 형태로 변환한 상태
    # 이 <a> 태그의 href를 favorites와 매핑하여 내부 링크로 변환
    text.gsub(%r{(<a\s+(?:href=["'])(https?://github\.com/[^/"']+)>)((?:[^<]*)?)(</a>)}i) do |match|
      github_url = $2
      link_text = $3
      favorite = Favorite.find_by("url LIKE ?", "#{github_url.chomp('/')}%")
      if favorite&.status == "done"
        "<a href=\"/favorites/#{favorite.id}\">#{link_text || github_url}</a>"
      else
        match # 그대로 유지
      end
    end
  end
end
