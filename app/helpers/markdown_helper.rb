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
  ALLOWED_ATTRIBUTES = %w[href].freeze

  def markdown(text)
    return "".html_safe if text.blank?

    sanitize(
      RENDERER.render(text.to_s),
      tags: ALLOWED_TAGS,
      attributes: ALLOWED_ATTRIBUTES
    )
  end
end
