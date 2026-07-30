# test/helpers/markdown_helper_test.rb
require "test_helper"

class MarkdownHelperTest < ActionView::TestCase
  include MarkdownHelper

  test "기본 markdown을 HTML로 렌더링합니다" do
    html = markdown("## 제목\n\n**굵게** 그리고 *기울임*\n\n- 항목 1\n- 항목 2")

    assert_includes html, "<h2>제목</h2>"
    assert_includes html, "<strong>굵게</strong>"
    assert_includes html, "<em>기울임</em>"
    assert_includes html, "<li>항목 1</li>"
  end

  test "script·iframe 등 위험 태그를 제거합니다 (XSS)" do
    html = markdown("안녕\n\n<script>alert('xss')</script>\n\n<iframe src='https://evil.example'></iframe>")

    refute_includes html, "<script"
    refute_includes html, "</script>"
    refute_includes html, "<iframe"
  end

  test "javascript: 프로토콜 링크를 차단합니다 (XSS)" do
    html = markdown("[클릭](javascript:alert(1))")

    refute_includes html, "javascript:"
    refute_includes html, "alert(1)"
  end

  test "onerror 등 이벤트 속성을 제거합니다 (XSS)" do
    html = markdown('<a href="https://example.com" onerror="alert(1)" onclick="alert(2)">링크</a>')

    assert_includes html, 'href="https://example.com"'
    refute_includes html, "onerror"
    refute_includes html, "onclick"
  end

  test "blockquote·표·코드블록이 유지됩니다" do
    html = markdown("> **용어** 설명\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n```ruby\nputs 'hi'\n```")

    assert_includes html, "<blockquote>"
    assert_includes html, "<strong>용어</strong>"
    assert_includes html, "<table>"
    assert_includes html, "<th>A</th>"
    assert_includes html, "<td>1</td>"
    assert_includes html, "<pre>"
    assert_includes html, "puts"
  end

  test "링크의 href를 유지합니다" do
    html = markdown("[예시](https://example.com/path)")

    assert_includes html, '<a href="https://example.com/path">예시</a>'
  end

  test "빈 입력은 빈 문자열을 반환합니다" do
    assert_equal "", markdown(nil)
    assert_equal "", markdown("")
  end
end
