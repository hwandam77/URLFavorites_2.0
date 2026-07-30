# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class UrlFavorites::Integrations::LlamaServer::ClientCompleteTest < ActiveSupport::TestCase
  def setup
    @original_backends = ENV["LLM_BACKENDS"]
    ENV["LLM_BACKENDS"] = [
      { "url" => "http://localhost:9993", "model" => "fast-model", "role" => "fast", "timeout" => 5 },
      { "url" => "http://localhost:9992", "model" => "heavy-model", "role" => "heavy", "timeout" => 5 }
    ].to_json
    WebMock.enable!
    WebMock.disable_net_connect!
  end

  def teardown
    ENV["LLM_BACKENDS"] = @original_backends
    WebMock.reset!
  end

  test "system 1개 + user 1개만 전송하고 response_format 을 강제하지 않는다" do
    stub_request(:post, "http://localhost:9993/v1/chat/completions")
      .with do |request|
        body = JSON.parse(request.body)
        assert_equal 1, body.fetch("messages").count { |m| m.fetch("role") == "system" }
        assert_equal 1, body.fetch("messages").count { |m| m.fetch("role") == "user" }
        assert_equal "sys prompt", body.fetch("messages").first.fetch("content")
        assert_equal "usr prompt", body.fetch("messages").last.fetch("content")
        assert_not body.key?("response_format")
        true
      end
      .to_return(status: 200, body: completion_response("섹션 본문").to_json)

    text, _model = UrlFavorites::Integrations::LlamaServer::Client.complete(
      system: "sys prompt",
      user: "usr prompt",
      backend_role: "fast"
    )

    assert_equal "섹션 본문", text
  end

  test "JSON 강제 없이 원문 그대로 반환하고 사용 모델명을 함께 반환한다" do
    stub_request(:post, "http://localhost:9993/v1/chat/completions")
      .to_return(status: 200, body: completion_response("## 제목\n본문 markdown").to_json)

    text, model = UrlFavorites::Integrations::LlamaServer::Client.complete(
      system: "s",
      user: "u",
      backend_role: "fast"
    )

    assert_equal "## 제목\n본문 markdown", text
    assert_equal "fast-model", model
  end

  test "blank content 이면 ServerError" do
    stub_request(:post, "http://localhost:9993/v1/chat/completions")
      .to_return(status: 200, body: completion_response("").to_json)
    stub_request(:post, "http://localhost:9992/v1/chat/completions")
      .to_return(status: 200, body: completion_response("").to_json)

    assert_raises(UrlFavorites::Integrations::LlamaServer::Client::ServerError) do
      UrlFavorites::Integrations::LlamaServer::Client.complete(system: "s", user: "u", backend_role: "fast")
    end
  end

  test "backend_role fast 우선 정렬 — fast 가 살아 있으면 heavy 는 호출하지 않는다" do
    fast_request = stub_request(:post, "http://localhost:9993/v1/chat/completions")
      .to_return(status: 200, body: completion_response("ok").to_json)
    heavy_request = stub_request(:post, "http://localhost:9992/v1/chat/completions")
      .to_return(status: 200, body: completion_response("ok").to_json)

    _text, model = UrlFavorites::Integrations::LlamaServer::Client.complete(
      system: "s",
      user: "u",
      backend_role: "fast"
    )

    assert_requested fast_request
    assert_not_requested heavy_request
    assert_equal "fast-model", model
  end

  test "fast 실패 시 heavy 로 폴백한다" do
    stub_request(:post, "http://localhost:9993/v1/chat/completions")
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
    stub_request(:post, "http://localhost:9992/v1/chat/completions")
      .to_return(status: 200, body: completion_response("heavy text").to_json)

    text, model = UrlFavorites::Integrations::LlamaServer::Client.complete(
      system: "s",
      user: "u",
      backend_role: "fast"
    )

    assert_equal "heavy text", text
    assert_equal "heavy-model", model
  end

  private

  def completion_response(content)
    { choices: [ { message: { content: content } } ] }
  end
end
