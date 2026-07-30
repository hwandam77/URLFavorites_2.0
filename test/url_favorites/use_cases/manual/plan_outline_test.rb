# frozen_string_literal: true

require "test_helper"

class PlanOutlineTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  OUTLINE_JSON = (1..8).map { |i| { heading: "섹션 #{i}", focus: "포인트 #{i}" } }.to_json

  setup do
    @favorite = Favorite.create!(
      url: "https://example.com/manual-#{SecureRandom.hex(4)}",
      status: "done",
      content_type: "webpage",
      raw_content: "매뉴얼 원문 " * 50,
      title: "Manual Target"
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
    @snapshot = @analysis.updated_at.to_f
    @complete_ok = ->(**_kwargs) { [ OUTLINE_JSON, "fast-gguf" ] }
  end

  test "정상 JSON 이면 섹션 N개 생성 + 잡 N개 발주" do
    UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, @complete_ok) do
      assert_enqueued_jobs(8, only: GenerateManualSectionJob) do
        UrlFavorites::UseCases::Manual::PlanOutline.call(
          favorite_id: @favorite.id,
          analysis_snapshot: @snapshot
        )
      end
    end

    sections = @analysis.analysis_sections.reload
    assert_equal 8, sections.size
    assert_equal (1..8).to_a, sections.map(&:position)
    assert_equal "섹션 1", sections.first.heading
    assert_equal "포인트 1", sections.first.focus
    assert_nil sections.first.body
  end

  test "코드펜스로 감싼 JSON 도 파싱한다" do
    fenced = ->(**_kwargs) { [ "```json\n#{OUTLINE_JSON}\n```", "fast-gguf" ] }

    UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, fenced) do
      UrlFavorites::UseCases::Manual::PlanOutline.call(
        favorite_id: @favorite.id,
        analysis_snapshot: @snapshot
      )
    end

    assert_equal 8, @analysis.analysis_sections.reload.size
    assert_equal "섹션 1", @analysis.analysis_sections.first.heading
  end

  test "파싱 실패 시 기본 템플릿으로 폴백 (예외 없음)" do
    garbage = ->(**_kwargs) { [ "JSON이 아닌 응답", "fast-gguf" ] }

    assert_nothing_raised do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, garbage) do
        UrlFavorites::UseCases::Manual::PlanOutline.call(
          favorite_id: @favorite.id,
          analysis_snapshot: @snapshot
        )
      end
    end

    sections = @analysis.analysis_sections.reload
    assert_equal 8, sections.size
    assert_equal "한줄요약", sections.first.heading
  end

  test "항목이 5개 미만이면 기본 템플릿으로 폴백" do
    short = ->(**_kwargs) { [ [ { heading: "하나", focus: "f" } ].to_json, "fast-gguf" ] }

    UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, short) do
      UrlFavorites::UseCases::Manual::PlanOutline.call(
        favorite_id: @favorite.id,
        analysis_snapshot: @snapshot
      )
    end

    sections = @analysis.analysis_sections.reload
    assert_equal 8, sections.size
    assert_equal "한줄요약", sections.first.heading
  end

  test "favorite 없으면 조용히 return" do
    assert_nothing_raised do
      UrlFavorites::UseCases::Manual::PlanOutline.call(favorite_id: 0, analysis_snapshot: 1.0)
    end
  end

  test "status 가 done 아니면 return" do
    @favorite.update!(status: "analyzing")
    UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, ->(**) { flunk "should not call" }) do
      UrlFavorites::UseCases::Manual::PlanOutline.call(
        favorite_id: @favorite.id,
        analysis_snapshot: @snapshot
      )
    end
    assert_equal 0, @analysis.analysis_sections.reload.size
  end

  test "analysis 없으면 return" do
    other = Favorite.create!(
      url: "https://example.com/no-analysis-#{SecureRandom.hex(4)}",
      status: "done",
      content_type: "webpage",
      raw_content: "원문"
    )
    UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, ->(**) { flunk "should not call" }) do
      assert_nothing_raised do
        UrlFavorites::UseCases::Manual::PlanOutline.call(favorite_id: other.id, analysis_snapshot: 1.0)
      end
    end
  end

  test "raw_content blank 이면 return" do
    @favorite.update!(raw_content: nil)
    @analysis.update!(raw_content: nil)
    UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, ->(**) { flunk "should not call" }) do
      UrlFavorites::UseCases::Manual::PlanOutline.call(
        favorite_id: @favorite.id,
        analysis_snapshot: @snapshot
      )
    end
    assert_equal 0, @analysis.analysis_sections.reload.size
  end

  test "snapshot 불일치 시 return" do
    UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, ->(**) { flunk "should not call" }) do
      UrlFavorites::UseCases::Manual::PlanOutline.call(
        favorite_id: @favorite.id,
        analysis_snapshot: @snapshot - 1.0
      )
    end
    assert_equal 0, @analysis.analysis_sections.reload.size
  end

  test "모든 섹션에 body 가 있으면 skip (멱등)" do
    @analysis.analysis_sections.create!(position: 1, heading: "기존", body: "완성")

    UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, ->(**) { flunk "should not call" }) do
      assert_no_enqueued_jobs(only: GenerateManualSectionJob) do
        UrlFavorites::UseCases::Manual::PlanOutline.call(
          favorite_id: @favorite.id,
          analysis_snapshot: @analysis.reload.updated_at.to_f
        )
      end
    end

    sections = @analysis.analysis_sections.reload
    assert_equal 1, sections.size
    assert_equal "기존", sections.first.heading
  end

  test "body 가 비어 있는 섹션이 하나라도 있으면 전부 destroy_all 후 재구축" do
    done_section = @analysis.analysis_sections.create!(position: 1, heading: "완성됨", body: "본문")
    @analysis.analysis_sections.create!(position: 2, heading: "미완성")

    UrlFavorites::Integrations::LlamaServer::Client.stub(:complete, @complete_ok) do
      assert_enqueued_jobs(8, only: GenerateManualSectionJob) do
        UrlFavorites::UseCases::Manual::PlanOutline.call(
          favorite_id: @favorite.id,
          analysis_snapshot: @analysis.reload.updated_at.to_f
        )
      end
    end

    sections = @analysis.analysis_sections.reload
    assert_equal 8, sections.size
    assert_not sections.map(&:id).include?(done_section.id)
    assert_equal "섹션 1", sections.first.heading
  end
end
