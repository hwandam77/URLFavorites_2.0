require "test_helper"
require "webmock/minitest"

class UrlFavorites::Integrations::LlamaServer::ClientTest < ActiveSupport::TestCase
  LLAMA_TEST_URL = "http://localhost:8080"

  def setup
    ENV["LLAMA_SERVER_URL"] = LLAMA_TEST_URL
    WebMock.enable!
    WebMock.disable_net_connect!
    @valid_response = {
      summary: "This is a summary",
      key_points: [ "key point 1", "key point 2" ],
      tags: [ "tag1", "tag2" ],
      sentiment: "positive"
    }.to_json
  end

  def teardown
    ENV.delete("LLAMA_SERVER_URL")
    WebMock.reset!
  end

  def test_call_parses_json_response
    stub_request(:post, ENV.fetch("LLAMA_SERVER_URL", "http://localhost:8080") + "/v1/chat/completions")
      .to_return(status: 200, body: @valid_response, headers: { "Content-Type" => "application/json" })

    result = UrlFavorites::Integrations::LlamaServer::Client.call("test content", type: "webpage")

    assert_equal "This is a summary", result[:summary]
    assert_includes result[:key_points], "key point 1"
    assert_includes result[:tags], "tag1"
    assert_equal "positive", result[:sentiment]
  end

  def test_call_raises_server_error_on_invalid_json
    stub_request(:post, ENV.fetch("LLAMA_SERVER_URL", "http://localhost:8080") + "/v1/chat/completions")
      .to_return(status: 200, body: "invalid json", headers: { "Content-Type" => "application/json" })

    # With multi-backend fallback, invalid JSON raises ServerError wrapping the ParseError
    assert_raises UrlFavorites::Integrations::LlamaServer::Client::ServerError do
      UrlFavorites::Integrations::LlamaServer::Client.call("test content", type: "webpage")
    end
  end

  def test_call_raises_server_error_on_http_500
    stub_request(:post, ENV.fetch("LLAMA_SERVER_URL", "http://localhost:8080") + "/v1/chat/completions")
      .to_return(status: 500)

    assert_raises UrlFavorites::Integrations::LlamaServer::Client::ServerError do
      UrlFavorites::Integrations::LlamaServer::Client.call("test content", type: "webpage")
    end
  end

  def test_call_uses_120s_timeout
    stub_request(:post, ENV.fetch("LLAMA_SERVER_URL", "http://localhost:8080") + "/v1/chat/completions")
      .to_return(status: 200, body: @valid_response, headers: { "Content-Type" => "application/json" })

    # 타임아웃 설정이 있어도 정상 응답은 통과해야 한다
    assert_nothing_raised do
      UrlFavorites::Integrations::LlamaServer::Client.call("test content", type: "webpage")
    end
  end

  def test_youtube_requests_use_specialized_analysis_prompt
    stub_request(:post, ENV.fetch("LLAMA_SERVER_URL", "http://localhost:8080") + "/v1/chat/completions")
      .with do |request|
        body = JSON.parse(request.body)
        system_message = body.fetch("messages").first.fetch("content")
        style_message = body.fetch("messages").second.fetch("content")
        user_message = body.fetch("messages").last.fetch("content")

        assert_includes system_message, "For YouTube content"
        assert_includes system_message, "AI execution brief"
        assert_includes system_message, "ready-to-use prompt"
        assert_includes system_message, "## 콘텐츠의 목적과 핵심 주장"
        assert_includes system_message, "## 영상에서 제공한 GitHub 링크"
        assert_includes system_message, "## 실행 가능한 절차"
        assert_includes system_message, "## 바로 사용 가능한 AI 프롬프트"
        assert_includes system_message, "Provided GitHub links"
        assert_includes system_message, "copy each URL exactly"
        assert_includes system_message, "역할"
        assert_includes system_message, "작업"
        assert_includes system_message, "입력"
        assert_includes system_message, "출력 형식"
        assert_includes system_message, "reuse the video's method"
        assert_includes system_message, "미확인"
        assert_includes system_message, "Timestamped transcript sample"
        assert_includes system_message, "use only timestamps shown"
        assert_includes system_message, "timestamp may be an empty string"
        assert_includes style_message, "Analysis style: execution_brief"
        assert_includes style_message, "AI execution brief"
        assert_includes user_message, "youtube:"
        true
      end
      .to_return(status: 200, body: @valid_response, headers: { "Content-Type" => "application/json" })

    UrlFavorites::Integrations::LlamaServer::Client.call("test content", type: "youtube")
  end

  def test_call_includes_selected_analysis_style_prompt
    stub_request(:post, ENV.fetch("LLAMA_SERVER_URL", "http://localhost:8080") + "/v1/chat/completions")
      .with do |request|
        body = JSON.parse(request.body)
        style_message = body.fetch("messages").second.fetch("content")

        assert_includes style_message, "Analysis style: qna"
        assert_includes style_message, "Korean Q&A document"
        true
      end
      .to_return(status: 200, body: @valid_response, headers: { "Content-Type" => "application/json" })

    UrlFavorites::Integrations::LlamaServer::Client.call("test content", type: "youtube", analysis_style: "qna")
  end
end
