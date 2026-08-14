# frozen_string_literal: true

require "test_helper"

class RefineAnalysisTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @favorite = Favorite.create!(
      url: "https://example.com/refine-#{SecureRandom.hex(4)}",
      status: "done",
      content_type: "webpage",
      raw_content: "cached body for refine",
      title: "Refine Target"
    )
    @analysis = @favorite.create_analysis!(
      summary: "initial summary",
      key_points: [ "a" ],
      tags: [ "initial" ],
      sentiment: "neutral",
      raw_content: @favorite.raw_content,
      model_used: "Qwen3.6-27B",
      analysis_style: "tutorial"
    )
    @snapshot = @analysis.updated_at.to_f
    @result = {
      summary: "refined summary",
      key_points: [ "r1" ],
      tags: [ "refined", "rails" ],
      sentiment: "positive",
      used_backend_role: "default",
      used_backend_model: "Qwen3.6-27B"
    }
  end

  test "favorite 없으면 조용히 return" do
    assert_nothing_raised do
      UrlFavorites::UseCases::Analysis::RefineAnalysis.call(
        favorite_id: 0,
        analysis_style: "tutorial",
        analysis_snapshot: 1.0
      )
    end
  end

  test "status 가 done 아니면 return" do
    @favorite.update!(status: "analyzing")
    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, ->(*) { flunk "should not call" }) do
      UrlFavorites::UseCases::Analysis::RefineAnalysis.call(
        favorite_id: @favorite.id,
        analysis_style: "tutorial",
        analysis_snapshot: @snapshot
      )
    end
    assert_equal "initial summary", @analysis.reload.summary
  end

  test "snapshot 불일치 시 폐기" do
    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, ->(*) { flunk "should not call" }) do
      UrlFavorites::UseCases::Analysis::RefineAnalysis.call(
        favorite_id: @favorite.id,
        analysis_style: "tutorial",
        analysis_snapshot: @snapshot - 1.0
      )
    end
    assert_equal "initial summary", @analysis.reload.summary
  end

  test "CAS 재검사 실패 시 조용히 폐기" do
    stub = ->(*_a, **_k) {
      @analysis.update!(summary: "newer generation")
      @result
    }

    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, stub) do
      UrlFavorites::UseCases::Analysis::RefineAnalysis.call(
        favorite_id: @favorite.id,
        analysis_style: "tutorial",
        analysis_snapshot: @snapshot
      )
    end

    @analysis.reload
    assert_equal "newer generation", @analysis.summary
  end

  test "성공 시 summary·model 갱신 및 reindex 발주" do
    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @result) do
      assert_enqueued_with(job: ReindexFavoriteJob, args: [ @favorite.id ]) do
        UrlFavorites::UseCases::Analysis::RefineAnalysis.call(
          favorite_id: @favorite.id,
          analysis_style: "tutorial",
          analysis_snapshot: @snapshot
        )
      end
    end

    @analysis.reload
    assert_equal "Qwen3.6-27B", @analysis.model_used
    assert_equal "refined summary", @analysis.summary
    assert_equal "done", @favorite.reload.status
  end

  test "실패 re-raise 시 favorite status/error 불변" do
    boom = ->(*_a, **_k) { raise UrlFavorites::Integrations::LlamaServer::Client::ServerError, "boom" }

    assert_raises(UrlFavorites::Integrations::LlamaServer::Client::ServerError) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, boom) do
        UrlFavorites::UseCases::Analysis::RefineAnalysis.call(
          favorite_id: @favorite.id,
          analysis_style: "tutorial",
          analysis_snapshot: @snapshot
        )
      end
    end

    @favorite.reload
    assert_equal "done", @favorite.status
    assert_nil(@favorite.error_message)
  end

  test "긴 raw_content 는 REFINE_INPUT_LIMIT(8,000자)로 절단" do
    long_content = "x" * 20_000
    @favorite.update!(raw_content: long_content)
    @analysis.update!(raw_content: long_content)
    captured = nil
    stub = ->(content, **_kwargs) {
      captured = content
      @result
    }

    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, stub) do
      UrlFavorites::UseCases::Analysis::RefineAnalysis.call(
        favorite_id: @favorite.id,
        analysis_style: "tutorial",
        analysis_snapshot: @analysis.reload.updated_at.to_f
      )
    end

    assert_equal UrlFavorites::UseCases::Analysis::RefineAnalysis::REFINE_INPUT_LIMIT, captured.length
  end
end
