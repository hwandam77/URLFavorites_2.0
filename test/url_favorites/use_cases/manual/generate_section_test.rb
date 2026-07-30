# frozen_string_literal: true

require "test_helper"

class GenerateSectionTest < ActiveSupport::TestCase
  setup do
    @favorite = Favorite.create!(
      url: "https://example.com/section-#{SecureRandom.hex(4)}",
      status: "done",
      content_type: "webpage",
      raw_content: "매뉴얼 원문 " * 50,
      title: "Section Target"
    )
    @analysis = @favorite.create_analysis!(
      summary: "fast summary",
      key_points: [ "a" ],
      tags: [ "manual" ],
      sentiment: "neutral",
      raw_content: @favorite.raw_content,
      analysis_tier: "fast",
      model_used: "fast-gguf",
      analysis_style: "onboarding_manual"
    )
    @section = @analysis.analysis_sections.create!(position: 1, heading: "핵심 기능", focus: "기능 설명")
    @other = @analysis.analysis_sections.create!(position: 2, heading: "활용 사례", focus: "사례")
    @snapshot = @analysis.reload.updated_at.to_f
  end

  test "정상 저장 — body 와 backend_model 기록" do
    complete = ->(**_kwargs) { [ "## 핵심 기능\n본문", "fast-gguf" ] }

    UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, complete) do
      UrlFavorites::UseCases::Manual::GenerateSection.call(
        analysis_id: @analysis.id,
        position: 1,
        analysis_snapshot: @snapshot
      )
    end

    @section.reload
    assert_equal "## 핵심 기능\n본문", @section.body
    assert_equal "fast-gguf", @section.backend_model
  end

  test "body 가 이미 있으면 재생성하지 않는다 (멱등)" do
    @section.update!(body: "기존 본문")

    UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, ->(**_kwargs) { flunk "should not call" }) do
      UrlFavorites::UseCases::Manual::GenerateSection.call(
        analysis_id: @analysis.id,
        position: 1,
        analysis_snapshot: @snapshot
      )
    end

    assert_equal "기존 본문", @section.reload.body
  end

  test "snapshot 불일치 시 skip" do
    UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, ->(**_kwargs) { flunk "should not call" }) do
      UrlFavorites::UseCases::Manual::GenerateSection.call(
        analysis_id: @analysis.id,
        position: 1,
        analysis_snapshot: @snapshot - 1.0
      )
    end

    assert_nil @section.reload.body
  end

  test "섹션이 없으면 조용히 return" do
    assert_nothing_raised do
      UrlFavorites::UseCases::Manual::GenerateSection.call(
        analysis_id: @analysis.id,
        position: 99,
        analysis_snapshot: @snapshot
      )
      UrlFavorites::UseCases::Manual::GenerateSection.call(
        analysis_id: 0,
        position: 1,
        analysis_snapshot: @snapshot
      )
    end
  end

  test "실패 시 favorite.status 불변 + re-raise" do
    boom = ->(**_kwargs) { raise UrlFavorites::Integrations::LlamaServer::Client::ServerError, "boom" }

    assert_raises(UrlFavorites::Integrations::LlamaServer::Client::ServerError) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, boom) do
        UrlFavorites::UseCases::Manual::GenerateSection.call(
          analysis_id: @analysis.id,
          position: 1,
          analysis_snapshot: @snapshot
        )
      end
    end

    assert_equal "done", @favorite.reload.status
    assert_nil @favorite.error_message
    assert_nil @section.reload.body
  end

  test "user 프롬프트에 다른 섹션 제목과 heading·focus 가 포함된다" do
    captured = nil
    complete = ->(**kwargs) {
      captured = kwargs
      [ "본문", "fast-gguf" ]
    }

    UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, complete) do
      UrlFavorites::UseCases::Manual::GenerateSection.call(
        analysis_id: @analysis.id,
        position: 1,
        analysis_snapshot: @snapshot
      )
    end

    assert_equal "fast", captured[:backend_role]
    assert_includes captured[:user], "핵심 기능"
    assert_includes captured[:user], "기능 설명"
    assert_includes captured[:user], "활용 사례"
    assert_includes captured[:user], @favorite.raw_content
  end
end
