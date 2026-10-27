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
    stub_request(:get, "http://localhost:9995/v1/models")
      .to_return(status: 200, body: { data: [ { id: "test-model" } ] }.to_json)

    assert UrlFavorites::Integrations::LlamaServer::HealthCheck.call
  end

  test "/health 가 5xx면 비정상" do
    stub_request(:get, "http://localhost:9995/health").to_return(status: 503)
    stub_request(:get, "http://localhost:9995/v1/models").to_return(status: 200, body: { data: [] }.to_json)

    assert_not UrlFavorites::Integrations::LlamaServer::HealthCheck.call
  end

  test "연결 거부 시 비정상 (vllm 프로세스 다운)" do
    stub_request(:get, "http://localhost:9995/health").to_raise(Faraday::ConnectionFailed.new("refused"))
    stub_request(:get, "http://localhost:9995/v1/models").to_return(status: 200, body: { data: [] }.to_json)

    assert_not UrlFavorites::Integrations::LlamaServer::HealthCheck.call
  end

  test "백엔드 중 하나라도 죽으면 전체 비정상" do
    ENV["LLM_BACKENDS"] = [
      { "url" => "http://localhost:9995", "model" => "a" },
      { "url" => "http://localhost:9994", "model" => "b" }
    ].to_json
    stub_request(:get, "http://localhost:9995/health").to_return(status: 200)
    stub_request(:get, "http://localhost:9995/v1/models")
      .to_return(status: 200, body: { data: [ { id: "a" } ] }.to_json)
    stub_request(:get, "http://localhost:9994/health").to_return(status: 503)
    stub_request(:get, "http://localhost:9994/v1/models").to_return(status: 200, body: { data: [] }.to_json)

    assert_not UrlFavorites::Integrations::LlamaServer::HealthCheck.call
  end

  test "설정한 모델이 서빙 목록에 없으면 비정상" do
    stub_request(:get, "http://localhost:9995/health").to_return(status: 200)
    stub_request(:get, "http://localhost:9995/v1/models")
      .to_return(status: 200, body: { data: [ { id: "other-model" } ] }.to_json)

    assert_not UrlFavorites::Integrations::LlamaServer::HealthCheck.call
  end

  test "설정한 모델이 서빙 목록에 있으면 정상" do
    stub_request(:get, "http://localhost:9995/health").to_return(status: 200)
    stub_request(:get, "http://localhost:9995/v1/models")
      .to_return(status: 200, body: { data: [ { id: "test-model" } ] }.to_json)

    assert UrlFavorites::Integrations::LlamaServer::HealthCheck.call
  end

  test "/v1/models 를 지원하지 않아도 /health 가 200이면 정상" do
    stub_request(:get, "http://localhost:9995/health").to_return(status: 200)
    stub_request(:get, "http://localhost:9995/v1/models").to_return(status: 404)

    assert UrlFavorites::Integrations::LlamaServer::HealthCheck.call
  end

  test "/v1/models 가 JSON 배열 본문이어도 조용히 정상 처리" do
    stub_request(:get, "http://localhost:9995/health").to_return(status: 200)
    stub_request(:get, "http://localhost:9995/v1/models")
      .to_return(status: 200, body: [ { id: "other-model" } ].to_json)

    assert UrlFavorites::Integrations::LlamaServer::HealthCheck.call
  end
end
