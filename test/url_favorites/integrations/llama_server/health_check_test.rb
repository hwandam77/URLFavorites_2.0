# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class UrlFavorites::Integrations::LlamaServer::HealthCheckTest < ActiveSupport::TestCase
  def setup
    @original_backends = ENV["LLM_BACKENDS"]
    ENV["LLM_BACKENDS"] = [ { "url" => "http://localhost:9995", "model" => "test-model" } ].to_json
    WebMock.enable!
    WebMock.disable_net_connect!
  end

  def teardown
    ENV["LLM_BACKENDS"] = @original_backends
    WebMock.reset!
  end

  test "백엔드 /health 가 200이면 정상" do
    stub_request(:get, "http://localhost:9995/health").to_return(status: 200)

    assert UrlFavorites::Integrations::LlamaServer::HealthCheck.call
  end

  test "/health 가 5xx면 비정상" do
    stub_request(:get, "http://localhost:9995/health").to_return(status: 503)

    assert_not UrlFavorites::Integrations::LlamaServer::HealthCheck.call
  end

  test "연결 거부 시 비정상 (vllm 프로세스 다운)" do
    stub_request(:get, "http://localhost:9995/health").to_raise(Faraday::ConnectionFailed.new("refused"))

    assert_not UrlFavorites::Integrations::LlamaServer::HealthCheck.call
  end

  test "백엔드 중 하나라도 죽으면 전체 비정상" do
    ENV["LLM_BACKENDS"] = [
      { "url" => "http://localhost:9995", "model" => "a" },
      { "url" => "http://localhost:9994", "model" => "b" }
    ].to_json
    stub_request(:get, "http://localhost:9995/health").to_return(status: 200)
    stub_request(:get, "http://localhost:9994/health").to_return(status: 503)

    assert_not UrlFavorites::Integrations::LlamaServer::HealthCheck.call
  end
end
