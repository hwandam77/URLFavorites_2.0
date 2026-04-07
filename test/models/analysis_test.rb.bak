require "test_helper"

class AnalysisTest < ActiveSupport::TestCase
  def setup
    @favorite = Favorite.create!(url: "https://example.com", content_type: "webpage")
  end

  test "favorite_id가 없으면 invalid" do
    analysis = Analysis.new(
      summary: "test",
      tags: "[]",
      key_points: "[]",
      sentiment: "neutral",
      model_used: "test-model",
      analyzed_at: Time.current
    )
    assert_not analysis.valid?
  end

  test "belongs_to :favorite" do
    analysis = Analysis.create!(
      favorite: @favorite,
      summary: "test summary",
      tags: '["tag1", "tag2"]',
      key_points: '[{"point": "key insight"}]',
      sentiment: "positive",
      model_used: "Qwen3-30B-A3B",
      analyzed_at: Time.current
    )
    assert_equal @favorite, analysis.favorite
  end

  test "sentiment는 positive, neutral, negative만 허용" do
    analysis = Analysis.new(
      favorite: @favorite,
      summary: "test",
      tags: "[]",
      key_points: "[]",
      sentiment: "invalid",
      model_used: "test",
      analyzed_at: Time.current
    )
    assert_not analysis.valid?
  end

  test "favorite 삭제 시 analysis도 삭제 (dependent: :destroy)" do
    Analysis.create!(
      favorite: @favorite,
      summary: "test",
      tags: "[]",
      key_points: "[]",
      sentiment: "neutral",
      model_used: "test",
      analyzed_at: Time.current
    )
    assert_difference "Analysis.count", -1 do
      @favorite.destroy
    end
  end
end
