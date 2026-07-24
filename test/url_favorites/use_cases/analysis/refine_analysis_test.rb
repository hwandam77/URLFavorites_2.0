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
      summary: "fast summary",
      key_points: [ "a" ],
      tags: [ "fast" ],
      sentiment: "neutral",
      raw_content: @favorite.raw_content,
      analysis_tier: "fast",
      model_used: "fast-gguf",
      analysis_style: "tutorial"
    )
    @snapshot = @analysis.updated_at.to_f
    @heavy_result = {
      summary: "heavy summary",
      key_points: [ "h1" ],
      tags: [ "heavy", "rails" ],
      sentiment: "positive",
      used_backend_role: "heavy",
      used_backend_model: "heavy-gguf"
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
    assert_equal "fast", @analysis.reload.analysis_tier
  end

  test "snapshot 불일치 시 폐기" do
    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, ->(*) { flunk "should not call" }) do
      UrlFavorites::UseCases::Analysis::RefineAnalysis.call(
        favorite_id: @favorite.id,
        analysis_style: "tutorial",
        analysis_snapshot: @snapshot - 1.0
      )
    end
    assert_equal "fast summary", @analysis.reload.summary
  end

  test "tier heavy 시 멱등 후처리 재실행" do
    @analysis.update!(analysis_tier: "heavy")
    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, ->(*) { flunk "should not call" }) do
      assert_enqueued_with(job: ReindexFavoriteJob, args: [ @favorite.id ]) do
        UrlFavorites::UseCases::Analysis::RefineAnalysis.call(
          favorite_id: @favorite.id,
          analysis_style: "tutorial",
          analysis_snapshot: @analysis.updated_at.to_f
        )
      end
    end
  end

  test "used_backend_role 이 heavy 가 아니면 raise 하고 favorite 불변" do
    bad = @heavy_result.merge(used_backend_role: "fast")
    before_status = @favorite.status
    before_error = @favorite.error_message

    assert_raises(UrlFavorites::Integrations::LlamaServer::Client::ServerError) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, bad) do
        UrlFavorites::UseCases::Analysis::RefineAnalysis.call(
          favorite_id: @favorite.id,
          analysis_style: "tutorial",
          analysis_snapshot: @snapshot
        )
      end
    end

    @favorite.reload
    assert_equal before_status, @favorite.status
    assert_nil @favorite.error_message
    assert_nil before_error
    assert_equal "fast", @analysis.reload.analysis_tier
  end

  test "CAS 재검사 실패 시 조용히 폐기" do
    call_count = 0
    stub = ->(*_a, **_k) {
      call_count += 1
      # LLM 호출 중 다른 세대가 갱신한 것처럼 snapshot 불일치 유도
      @analysis.update!(summary: "newer generation")
      @heavy_result
    }

    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, stub) do
      UrlFavorites::UseCases::Analysis::RefineAnalysis.call(
        favorite_id: @favorite.id,
        analysis_style: "tutorial",
        analysis_snapshot: @snapshot
      )
    end

    assert_equal 1, call_count
    @analysis.reload
    assert_equal "fast", @analysis.analysis_tier
    assert_equal "newer generation", @analysis.summary
  end

  test "성공 시 tier·model·summary 갱신 및 reindex 발주" do
    UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @heavy_result) do
      assert_enqueued_with(job: ReindexFavoriteJob, args: [ @favorite.id ]) do
        UrlFavorites::UseCases::Analysis::RefineAnalysis.call(
          favorite_id: @favorite.id,
          analysis_style: "tutorial",
          analysis_snapshot: @snapshot
        )
      end
    end

    @analysis.reload
    assert_equal "heavy", @analysis.analysis_tier
    assert_equal "heavy-gguf", @analysis.model_used
    assert_equal "heavy summary", @analysis.summary
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
end
