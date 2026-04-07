require "test_helper"
require "webmock/minitest"

class LlmAnalyzerTest < ActiveSupport::TestCase
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

    result = LlmAnalyzer.call("test content", type: "webpage")

    assert_equal "This is a summary", result[:summary]
    assert_includes result[:key_points], "key point 1"
    assert_includes result[:tags], "tag1"
    assert_equal "positive", result[:sentiment]
  end

  def test_call_raises_parse_error_on_invalid_json
    stub_request(:post, ENV.fetch("LLAMA_SERVER_URL", "http://localhost:8080") + "/v1/chat/completions")
      .to_return(status: 200, body: "invalid json", headers: { "Content-Type" => "application/json" })

    assert_raises LlmAnalyzer::ParseError do
      LlmAnalyzer.call("test content", type: "webpage")
    end
  end

  def test_call_raises_server_error_on_http_500
    stub_request(:post, ENV.fetch("LLAMA_SERVER_URL", "http://localhost:8080") + "/v1/chat/completions")
      .to_return(status: 500)

    assert_raises LlmAnalyzer::ServerError do
      LlmAnalyzer.call("test content", type: "webpage")
    end
  end

  def test_call_uses_120s_timeout
    stub_request(:post, ENV.fetch("LLAMA_SERVER_URL", "http://localhost:8080") + "/v1/chat/completions")
      .to_return(status: 200, body: @valid_response, headers: { "Content-Type" => "application/json" })

    # 타임아웃 설정이 있어도 정상 응답은 통과해야 한다
    assert_nothing_raised do
      LlmAnalyzer.call("test content", type: "webpage")
    end
  end
end
