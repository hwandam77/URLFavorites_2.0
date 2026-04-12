require "test_helper"
require "webmock/minitest"

class LlmAnalyzerFallbackTest < ActiveSupport::TestCase
  def setup
    @original_backends = ENV["LLM_BACKENDS"]
  end

  def teardown
    ENV["LLM_BACKENDS"] = @original_backends
  end

  test "uses first available backend" do
    ENV["LLM_BACKENDS"] = [
      { "url" => "http://localhost:9999", "model" => "test", "timeout" => 5 }.to_json
    ].to_json

    stub_request(:post, "http://localhost:9999/v1/chat/completions")
      .to_return(status: 200, body: valid_response.to_json)

    result = LlmAnalyzer.call("test content", type: "webpage")
    assert_equal "Test summary", result[:summary]
  end

  test "falls back to second backend when first fails" do
    ENV["LLM_BACKENDS"] = [
      { "url" => "http://localhost:9998", "model" => "test", "timeout" => 5 }.to_json,
      { "url" => "http://localhost:9999", "model" => "test", "timeout" => 5 }.to_json
    ].to_json

    stub_request(:post, "http://localhost:9998/v1/chat/completions")
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
    stub_request(:post, "http://localhost:9999/v1/chat/completions")
      .to_return(status: 200, body: valid_response.to_json)

    result = LlmAnalyzer.call("test content", type: "webpage")
    assert_equal "Test summary", result[:summary]
  end

  test "raises error when all backends fail" do
    ENV["LLM_BACKENDS"] = [
      { "url" => "http://localhost:9998", "model" => "test", "timeout" => 5 }.to_json
    ].to_json

    stub_request(:post, "http://localhost:9998/v1/chat/completions")
      .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

    assert_raises(LlmAnalyzer::ServerError) do
      LlmAnalyzer.call("test content", type: "webpage")
    end
  end

  test "falls back when first backend returns 500" do
    ENV["LLM_BACKENDS"] = [
      { "url" => "http://localhost:9998", "model" => "test", "timeout" => 5 }.to_json,
      { "url" => "http://localhost:9999", "model" => "test", "timeout" => 5 }.to_json
    ].to_json

    stub_request(:post, "http://localhost:9998/v1/chat/completions")
      .to_return(status: 500, body: "Internal Server Error")
    stub_request(:post, "http://localhost:9999/v1/chat/completions")
      .to_return(status: 200, body: valid_response.to_json)

    result = LlmAnalyzer.call("test content", type: "webpage")
    assert_equal "Test summary", result[:summary]
  end

  test "falls back when first backend returns ParseError due to missing keys" do
    ENV["LLM_BACKENDS"] = [
      { "url" => "http://localhost:9998", "model" => "test", "timeout" => 5 }.to_json,
      { "url" => "http://localhost:9999", "model" => "test", "timeout" => 5 }.to_json
    ].to_json

    # Response is valid JSON but missing required keys
    stub_request(:post, "http://localhost:9998/v1/chat/completions")
      .to_return(status: 200, body: { summary: "Only summary" }.to_json)
    stub_request(:post, "http://localhost:9999/v1/chat/completions")
      .to_return(status: 200, body: valid_response.to_json)

    result = LlmAnalyzer.call("test content", type: "webpage")
    assert_equal "Test summary", result[:summary]
  end

  test "falls back when first backend times out" do
    ENV["LLM_BACKENDS"] = [
      { "url" => "http://localhost:9998", "model" => "test", "timeout" => 1 }.to_json,
      { "url" => "http://localhost:9999", "model" => "test", "timeout" => 5 }.to_json
    ].to_json

    stub_request(:post, "http://localhost:9998/v1/chat/completions")
      .to_timeout
    stub_request(:post, "http://localhost:9999/v1/chat/completions")
      .to_return(status: 200, body: valid_response.to_json)

    result = LlmAnalyzer.call("test content", type: "webpage")
    assert_equal "Test summary", result[:summary]
  end

  private

  def valid_response
    {
      summary: "Test summary",
      key_points: ["point1"],
      tags: ["tag1"],
      sentiment: "neutral"
    }
  end
end