require "test_helper"
require "webmock/minitest"

class AnalyzeWebpageJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    WebMock.enable!
    WebMock.disable_net_connect!
    @favorite = Favorite.create!(url: "https://example.com", status: "pending", content_type: "webpage")
    @scraper_result = { title: "제목", description: "설명", body_text: "본문 내용", og_image: nil }
    @analyzer_result = {
      summary: "요약 내용",
      key_points: [ "핵심 1", "핵심 2" ],
      tags: [ "rails", "ruby" ],
      sentiment: "positive"
    }
  end

  teardown do
    WebMock.reset!
  end

  test "성공 시 pending → analyzing → done 상태 전이 및 Analysis 생성" do
    UrlFavorites::Integrations::Webpage::Scraper.stub(:call, @scraper_result) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @analyzer_result) do
        AnalyzeWebpageJob.perform_now(@favorite.id)

        @favorite.reload
        assert_equal "done", @favorite.status
        assert_not_nil @favorite.analysis
        assert_equal "요약 내용", @favorite.analysis.summary
        assert_equal [ "rails", "ruby" ], @favorite.analysis.tags
        assert_equal "positive", @favorite.analysis.sentiment
      end
    end
  end

  test "분석 완료 시 검색 인덱싱 잡을 발주한다" do
    UrlFavorites::Integrations::Webpage::Scraper.stub(:call, @scraper_result) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @analyzer_result) do
        assert_enqueued_with(job: ReindexFavoriteJob, args: [ @favorite.id ]) do
          AnalyzeWebpageJob.perform_now(@favorite.id)
        end
      end
    end
  end

  test "raw_content 에 스크래퍼 결과를 캐싱한다" do
    UrlFavorites::Integrations::Webpage::Scraper.stub(:call, @scraper_result) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @analyzer_result) do
        AnalyzeWebpageJob.perform_now(@favorite.id)

        assert_not_nil @favorite.reload.analysis.raw_content
      end
    end
  end

  test "스크래핑 실패 시 status = failed" do
    UrlFavorites::Integrations::Webpage::Scraper.stub(:call, ->(_url) { raise UrlFavorites::Integrations::Webpage::Scraper::FetchError, "스크래핑 실패" }) do
      AnalyzeWebpageJob.perform_now(@favorite.id)

      @favorite.reload
      assert_equal "failed", @favorite.status
    end
  end

  test "LLM 분석 실패 시 status = failed" do
    UrlFavorites::Integrations::Webpage::Scraper.stub(:call, @scraper_result) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, ->(*_args) { raise UrlFavorites::Integrations::LlamaServer::Client::ServerError, "LLM 오류" }) do
        AnalyzeWebpageJob.perform_now(@favorite.id)

        @favorite.reload
        assert_equal "failed", @favorite.status
      end
    end
  end

  test "완료된 분석이 있으면 재분석 실패 시에도 done 유지" do
    UrlFavorites::Integrations::Webpage::Scraper.stub(:call, @scraper_result) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @analyzer_result) do
        AnalyzeWebpageJob.perform_now(@favorite.id)
      end
      assert_equal "done", @favorite.reload.status

      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, ->(*_args) { raise UrlFavorites::Integrations::LlamaServer::Client::ServerError, "LLM 오류" }) do
        AnalyzeWebpageJob.perform_now(@favorite.id)
      end

      @favorite.reload
      assert_equal "done", @favorite.status
      assert_match "LLM 오류", @favorite.error_message
    end
  end

  test "재실행 시 Analysis 를 덮어쓴다 (upsert)" do
    UrlFavorites::Integrations::Webpage::Scraper.stub(:call, @scraper_result) do
      UrlFavorites::Integrations::LlamaServer::Client.stub(:call, @analyzer_result) do
        AnalyzeWebpageJob.perform_now(@favorite.id)
        AnalyzeWebpageJob.perform_now(@favorite.id)

        assert_equal 1, Analysis.where(favorite_id: @favorite.id).count
      end
    end
  end
end
