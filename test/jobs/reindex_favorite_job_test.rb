# test/jobs/reindex_favorite_job_test.rb
require "test_helper"

class ReindexFavoriteJobTest < ActiveSupport::TestCase
  def test_performs_job_and_calls_favorite_search_indexer_for_single_favorite
    fav = Favorite.create!(title: "Job Test", url: "https://example.com/job", content_type: "webpage", status: "done")
    indexed = false
    UrlFavorites::Integrations::Search::Indexer.stub(:index, ->(f) { indexed = true if f.id == fav.id }) do
      ReindexFavoriteJob.new.perform(fav.id)
    end
    assert indexed
  end

  def test_calls_reindex_all_when_no_favorite_id_given
    reindexed = false
    UrlFavorites::Integrations::Search::Indexer.stub(:reindex_all, -> { reindexed = true }) do
      ReindexFavoriteJob.new.perform(nil)
    end
    assert reindexed
  end

  def test_skips_silently_when_favorite_not_found
    assert_nothing_raised do
      ReindexFavoriteJob.new.perform(999999)
    end
  end

  def test_enqueues_to_default_queue
    assert_equal "default", ReindexFavoriteJob.queue_name
  end
end
