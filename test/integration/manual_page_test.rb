# test/integration/manual_page_test.rb
require "test_helper"

class ManualPageTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as
    @favorite = Favorite.create!(
      title: "매뉴얼 대상",
      url: "https://example.com/manual-target",
      content_type: "webpage",
      status: "done"
    )
    @analysis = Analysis.create!(favorite: @favorite, summary: "s", tags: [], key_points: [])
  end

  test "매뉴얼 페이지가 섹션 heading과 본문 markdown을 렌더링합니다" do
    create_section(1, "개요", "## 첫 단계\n\n> **용어** 북마크\n\n- 항목 A")
    create_section(2, "심화", "본문 **강조**")

    get manual_favorite_url(@favorite)

    assert_response :success
    assert_select "section#section-1 h2", text: "개요"
    assert_select "section#section-2 h2", text: "심화"
    assert_select "nav a[href='#section-1']", text: "개요"
    assert_select "section#section-1 .manual-body h2", text: "첫 단계"
    assert_select "section#section-1 .manual-body blockquote strong", text: "용어"
    assert_select "section#section-2 .manual-body strong", text: "강조"
    assert_includes response.body, "qwen-test"
    assert_includes response.body, "섹션 2개"
  end

  test "본문이 없는 섹션은 생성 중 표기를 보여줍니다" do
    create_section(1, "완료 섹션", "본문")
    create_section(2, "미완료 섹션", nil)

    get manual_favorite_url(@favorite)

    assert_response :success
    assert_select "section#section-2 h2", text: "미완료 섹션"
    assert_select "section#section-2", text: /생성 중/
  end

  test "상세페이지에 매뉴얼 보기 링크가 표시됩니다" do
    create_section(1, "개요", "본문")

    get favorite_url(@favorite)

    assert_response :success
    assert_select "a[href='#{manual_favorite_path(@favorite)}']", text: /온보딩 매뉴얼 보기/
  end

  test "상세페이지에 생성 진행 상황이 표시됩니다" do
    create_section(1, "개요", "본문")
    create_section(2, "심화", nil)

    get favorite_url(@favorite)

    assert_response :success
    assert_select "a[href='#{manual_favorite_path(@favorite)}']", text: /매뉴얼 생성 중 \(1\/2 섹션\)/
  end

  private

  def create_section(position, heading, body)
    AnalysisSection.create!(
      analysis: @analysis, position: position, heading: heading,
      body: body, backend_model: "qwen-test"
    )
  end
end
