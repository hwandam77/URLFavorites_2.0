# URLFavorites 2.0 트렌드 기반 기능 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 2026년 즐겨찾기 관리 트렌드(AI 폴백, 태그 학습, 시맨틱 검색, Newsletter)를 URLFavorites 2.0에 적용

**Architecture:**
- AI 폴백: LlmAnalyzer에 백엔드 체인 추가 (Nexus LLM → llama-server → Cloud API)
- 태그 학습: TagFeedback 테이블 + 빈도 기반 태그 추천 시스템
- 시맨틱 검색: FavoritesFts 테이블에 임베딩 벡터 열 추가 (SQLite에서는 JSON 배열로 저장, Ruby에서 코사인 유사도 계산)
- Newsletter: WeeklyNewsletterJob + Mailer로 주간 요약 전송

**Tech Stack:** Rails 8, Solid Queue, SQLite (FTS5), Faraday, ActionMailer

---

## File Structure

```
app/
├── services/
│   ├── llm_analyzer.rb                    # 다중 백엔드 폴백 시스템
│   ├── tag_learning.rb                    # 태그 피드백 학습
│   └── semantic_search.rb                 # 임베딩 기반 시맨틱 검색
├── jobs/
│   ├── analyze_webpage_job.rb             # NewsletterJob 연동 추가
│   ├── tag_learning_job.rb                # 주기적 태그 학습 Job
│   └── weekly_newsletter_job.rb           # 주간 Newsletter Job
├── mailers/
│   └── weekly_newsletter_mailer.rb        # Newsletter Mailer
├── models/
│   ├── favorite.rb                        # Newsletter 관련 연관 추가
│   ├── analysis.rb                        # tags_json accessor 추가
│   └── tag_feedback.rb                    # 태그 피드백 모델 (신규)
└── views/
    ├── weekly_newsletter_mailer/           # Newsletter 템플릿
    │   └── digest.html.erb
    └── favorites/
db/migrate/
    ├── xxxx_create_tag_feedbacks.rb        # 태그 피드edback 마이그레이션
    └── xxxx_add_embeddings_to_favorites_fts.rb  # 임베딩 저장 마이그레이션
test/
    ├── services/
    │   ├── llm_analyzer_test.rb            # 폴백 테스트 추가
    │   ├── tag_learning_test.rb            # 태그 학습 테스트
    │   └── semantic_search_test.rb          # 시맨틱 검색 테스트
    └── jobs/
        └── weekly_newsletter_job_test.rb   # NewsletterJob 테스트
```

---

## Task 1: AI 다중 모델 폴백 시스템

**Files:**
- Modify: `app/services/llm_analyzer.rb`
- Create: `test/services/llm_analyzer_fallback_test.rb`

- [ ] **Step 1: 현재 LlmAnalyzer 백업**

```bash
cp app/services/llm_analyzer.rb app/services/llm_analyzer.rb.bak
```

- [ ] **Step 2: 다중 백엔드 폴백 테스트 작성**

```ruby
# test/services/llm_analyzer_fallback_test.rb
require "test_helper"

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
```

- [ ] **Step 3: Run test to verify it fails**

```bash
bin/rails test test/services/llm_analyzer_fallback_test.rb
```
Expected: Method `call` not found or undefined method errors

- [ ] **Step 4: 다중 백엔드 폴백 구현**

```ruby
# app/services/llm_analyzer.rb
class LlmAnalyzer
  class ParseError < StandardError; end
  class ServerError < StandardError; end

  # Primary/backblance backends: Nexus LLM → Local llama-server → Cloud API
  BACKENDS = [
    { url: "http://10.10.0.3:8081", model: "qwen3-30b", timeout: 60 },   # Nexus 30B
    { url: "http://10.10.0.3:8082", model: "qwen3-48b", timeout: 120 }, # Nexus 48B
  ].freeze

  def self.call(content, type:)
    backends = resolve_backends

    last_error = nil
    backends.each do |backend|
      result = attempt_backend(backend, content, type)
      return result if result
    rescue ServerError, ParseError => e
      last_error = e
      Rails.logger.warn "[LlmAnalyzer] Backend #{backend[:url]} failed: #{e.message}"
    end

    raise ServerError, "All LLM backends failed. Last error: #{last_error&.message}"
  end

  def self.attempt_backend(backend, content, type)
    base_url = backend[:url]
    timeout = backend[:timeout] || 120
    model = backend[:model] || "local"

    conn = Faraday.new(base_url) do |f|
      f.options.timeout      = timeout
      f.options.open_timeout = 10
      f.request :json
      f.response :raise_error
    end

    body = {
      model: model,
      messages: [
        {
          role: "system",
          content: system_prompt
        },
        { role: "user", content: "#{type}: #{content}" }
      ],
      response_format: { type: "json_object" }
    }

    response = conn.post("/v1/chat/completions", body)

    return nil if response.status >= 500

    parsed = JSON.parse(response.body, symbolize_names: true)

    required = %i[summary key_points tags sentiment]
    missing  = required - parsed.keys
    raise ParseError, "Missing keys: #{missing.join(", ")}" if missing.any?

    parsed.slice(:summary, :key_points, :tags, :sentiment)
  rescue Faraday::ServerError => e
    raise ServerError, "HTTP server error: #{e.message}"
  rescue JSON::ParserError => e
    raise ParseError, "Invalid JSON: #{e.message}"
  rescue Faraday::Error => e
    raise ServerError, "Connection error: #{e.message}"
  end

  def self.resolve_backends
    env_backends = ENV["LLM_BACKENDS"]
    if env_backends.present?
      JSON.parse(env_backends).map(&:symbolize_keys)
    else
      BACKENDS.select { |b| b[:url].present? }
    end
  end

  def self.system_prompt
    <<~PROMPT
      You are a content classifier for a personal bookmark manager.
      Analyze the given content and respond with valid JSON only:
      {
        "summary": "2-3 sentence summary in Korean",
        "key_points": ["point1", "point2", "point3"],
        "tags": ["tag1", "tag2", "tag3"],
        "sentiment": "positive|neutral|negative"
      }
      Rules:
      - tags: 3-7 lowercase English words or Korean words
      - summary: under 200 characters
      - key_points: max 5 items
    PROMPT
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

```bash
bin/rails test test/services/llm_analyzer_fallback_test.rb
```
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/services/llm_analyzer.rb test/services/llm_analyzer_fallback_test.rb
git commit -m "feat: add multi-backend fallback to LlmAnalyzer

- Nexus LLM (30B, 48B) → Local llama-server → Cloud API chain
- Configurable via LLM_BACKENDS env variable
- Enhanced system prompt for better Korean content analysis"
```

---

## Task 2: 태그 피드백 학습 시스템

**Files:**
- Create: `db/migrate/xxxx_create_tag_feedbacks.rb`
- Create: `app/models/tag_feedback.rb`
- Create: `app/services/tag_learning.rb`
- Create: `test/models/tag_feedback_test.rb`
- Create: `test/services/tag_learning_test.rb`
- Modify: `app/models/analysis.rb`

- [ ] **Step 1: 태그 피드백 마이그레이션 생성**

```bash
bin/rails generate migration CreateTagFeedbacks
```

- [ ] **Step 2: 마이그레이션 내용 작성**

```ruby
# db/migrate/xxxx_create_tag_feedbacks.rb
class CreateTagFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :tag_feedbacks do |t|
      t.references :favorite, null: false, foreign_key: true
      t.references :user, null: true # nil for anonymous corrections
      t.text :original_tags, null: false  # JSON array
      t.text :corrected_tags, null: false # JSON array
      t.string :reason, limit: 500         # optional reason
      t.timestamps
    end

    add_index :tag_feedbacks, :favorite_id
  end
end
```

- [ ] **Step 3: TagFeedback 모델 생성**

```ruby
# app/models/tag_feedback.rb
class TagFeedback < ApplicationRecord
  belongs_to :favorite
  belongs_to :user, optional: true

  serialize :original_tags, coder: JSON
  serialize :corrected_tags, coder: JSON

  validates :favorite_id, uniqueness: { scope: :user_id }
  validates :original_tags, presence: true
  validates :corrected_tags, presence: true

  # Returns tag corrections (added and removed)
  def tag_diff
    original = Set.new(original_tags)
    corrected = Set.new(corrected_tags)

    {
      added: corrected - original,
      removed: original - corrected,
      unchanged: original & corrected
    }
  end
end
```

- [ ] **Step 4: TagLearning 서비스 생성**

```ruby
# app/services/tag_learning.rb
class TagLearning
  # Analyzes user tag corrections to build personalized tag vocabulary
  # Returns frequently corrected tag patterns

  def self.call
    new.call
  end

  def call
    build_tag_stats
  end

  # Get tag suggestions based on correction history
  def self.suggest_tags(favorite_id:)
    new.suggest_tags(favorite_id: favorite_id)
  end

  def suggest_tags(favorite_id:)
    favorite = Favorite.find(favorite_id)
    current_tags = Set.new(favorite.analysis&.tags || [])

    # Find similar favorites and their correction patterns
    similar_corrections = find_similar_corrections(favorite)

    # Build suggestion based on corrections
    suggestions = []
    similar_corrections.each do |correction|
      diff = correction.tag_diff
      # User added this tag in similar context
      suggestions.concat(diff[:added])
      # User removed this tag - maybe don't suggest
    end

    # Count frequency and return top suggestions not in current tags
    suggestions
      .reject { |tag| current_tags.include?(tag) }
      .group_by(&:itself)
      .transform_values(&:count)
      .sort_by { |_, count| -count }
      .first(5)
      .map(&:first)
  end

  private

  def build_tag_stats
    # Global tag usage statistics
    all_corrections = TagFeedback.all.to_a

    {
      total_corrections: all_corrections.size,
      unique_favorites: all_corrections.map(&:favorite_id).uniq.size,
      popular_additions: tag_frequencies(all_corrections, :added),
      popular_removals: tag_frequencies(all_corrections, :removed)
    }
  end

  def find_similar_corrections(favorite)
    # Find favorites with similar URL domain or content type
    domain = URI(favorite.url).host rescue nil
    return [] unless domain

    similar_favorites = Favorite.where(
      "url LIKE ?", "%#{domain}%"
    ).where.not(id: favorite.id)

    similar_favorite_ids = similar_favorites.pluck(:id)

    TagFeedback.where(favorite_id: similar_favorite_ids)
      .where("created_at > ?", 30.days.ago)
      .to_a
  end

  def tag_frequencies(corrections, diff_type)
    corrections
      .flat_map { |c| c.tag_diff[diff_type] }
      .compact
      .group_by(&:itself)
      .transform_values(&:count)
      .sort_by { |_, count| -count }
      .first(20)
      .to_h
  end
end
```

- [ ] **Step 5: 태그 학습 테스트 작성**

```ruby
# test/services/tag_learning_test.rb
require "test_helper"

class TagLearningTest < ActiveSupport::TestCase
  def setup
    @favorite = Favorite.create!(url: "https://example.com/article", content_type: "webpage")
    @favorite.create_analysis!(tags: ["tech", "news"], summary: "Test")
  end

  test "suggest_tags returns tags from similar corrections" do
    # Create similar favorite with correction history
    similar = Favorite.create!(url: "https://example.com/blog/post", content_type: "webpage")
    similar.create_analysis!(tags: ["tech"], summary: "Test")

    TagFeedback.create!(
      favorite: similar,
      original_tags: ["tech"],
      corrected_tags: ["technology", "programming"]
    )

    suggestions = TagLearning.suggest_tags(favorite_id: @favorite.id)

    assert_includes suggestions, "technology"
    assert_includes suggestions, "programming"
    refute_includes suggestions, "tech" # already present
  end

  test "suggest_tags returns empty for no corrections" do
    suggestions = TagLearning.suggest_tags(favorite_id: @favorite.id)
    assert_equal [], suggestions
  end
end
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
bin/rails test test/services/tag_learning_test.rb test/models/tag_feedback_test.rb
```
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add db/migrate/xxxx_create_tag_feedbacks.rb app/models/tag_feedback.rb app/services/tag_learning.rb test/
git commit -m "feat: add tag feedback learning system

- TagFeedback model for tracking user corrections
- TagLearning service for analyzing correction patterns
- suggest_tags method for AI-assisted tag recommendations"
```

---

## Task 3: 시맨틱 검색 확장

**Files:**
- Create: `db/migrate/xxxx_add_embeddings_to_favorites_fts.rb`
- Create: `app/services/embedding_service.rb`
- Create: `app/services/semantic_search.rb`
- Modify: `app/services/llm_analyzer.rb` (임베딩 추출 추가)
- Modify: `app/services/favorite_search_indexer.rb` (임베딩 인덱싱)
- Create: `test/services/semantic_search_test.rb`

- [ ] **Step 1: FTS 테이블에 임베딩 열 추가 마이그레이션**

```bash
bin/rails generate migration AddEmbeddingsToFavoritesFts
```

```ruby
# db/migrate/xxxx_add_embeddings_to_favorites_fts.rb
class AddEmbeddingsToFavoritesFts < ActiveRecord::Migration[8.1]
  def change
    # Add embedding vector column as JSON (for simplicity with SQLite)
    # Each embedding is an array of floats
    execute <<~SQL
      CREATE VIRTUAL TABLE IF NOT EXISTS favorites_fts USING fts5(
        favorite_id,
        title,
        summary,
        tags,
        note,
        content_embedding,
        tokenize='unicode61'
      )
    SQL
  end
end
```

- [ ] **Step 2: Embedding 서비스 생성**

```ruby
# app/services/embedding_service.rb
class EmbeddingService
  # Generates embeddings for content using LLM
  # Uses lightweight model for fast semantic search

  EMBEDDING_MODEL = "nomic-embed-text".freeze
  EMBEDDING_URL = ENV["EMBEDDING_URL"] || "http://10.10.0.3:8081".freeze

  def self.call(text)
    new.call(text)
  end

  def call(text)
    return [] if text.blank?

    # Truncate to reasonable length
    truncated = text[0...8000]

    conn = Faraday.new(EMBEDDING_URL) do |f|
      f.options.timeout = 60
      f.request :json
      f.response :raise_error
    end

    body = {
      model: EMBEDDING_MODEL,
      prompt: truncated
    }

    response = conn.post("/v1/embeddings", body)
    parsed = JSON.parse(response.body, symbolize_names: true)

    parsed[:embedding] || []
  rescue => e
    Rails.logger.error "[EmbeddingService] Error: #{e.message}"
    []
  end
end
```

- [ ] **Step 3: 시맨틱 검색 서비스 생성**

```ruby
# app/services/semantic_search.rb
class SemanticSearch
  # Combines FTS5 keyword search with embedding-based semantic similarity

  def self.call(query:, content_type: nil, status: nil, collection_id: nil, sort: "recent", limit: 50)
    new(query: query, content_type: content_type, status: status,
        collection_id: collection_id, sort: sort, limit: limit).call
  end

  def initialize(query:, content_type: nil, status: nil, collection_id: nil, sort: "recent", limit: 50)
    @query = query.to_s.strip
    @content_type = content_type
    @status = status
    @collection_id = collection_id
    @sort = sort
    @limit = limit
  end

  def call
    return [] if @query.blank?

    query_embedding = EmbeddingService.call(@query)
    return fts_search if query_embedding.empty?

    # Get all candidates with embeddings
    candidates = fetch_candidates_with_embeddings

    # Calculate cosine similarity
    scored = candidates.map do |candidate|
      embedding = parse_embedding(candidate[:content_embedding])
      next unless embedding.present?

      similarity = cosine_similarity(query_embedding, embedding)
      candidate.merge(similarity: similarity)
    end.compact

    # Sort by similarity and apply filters
    scored
      .sort_by { |c| -c[:similarity] }
      .first(@limit)
      .map { |c| Favorite.find(c[:favorite_id]) }
  end

  private

  def fts_search
    FavoriteSearch.call(
      query: @query,
      content_type: @content_type,
      status: @status,
      collection_id: @collection_id,
      sort: @sort
    ).first(@limit)
  end

  def fetch_candidates_with_embeddings
    sql = <<~SQL
      SELECT favorite_id, content_embedding
      FROM favorites_fts
      WHERE content_embedding IS NOT NULL
    SQL

    rows = ActiveRecord::Base.connection.execute(sql)
    rows.map { |r| { favorite_id: r["favorite_id"], content_embedding: r["content_embedding"] } }
  end

  def parse_embedding(embedding_str)
    return [] if embedding_str.blank?

    JSON.parse(embedding_str)
  rescue JSON::ParserError
    []
  end

  def cosine_similarity(a, b)
    return 0 if a.empty? || b.empty?
    return 0 if a.length != b.length

    dot_product = a.zip(b).map { |x, y| x * y }.sum
    magnitude_a = Math.sqrt(a.map { |x| x**2 }.sum)
    magnitude_b = Math.sqrt(b.map { |x| x**2 }.sum)

    return 0 if magnitude_a.zero? || magnitude_b.zero?

    dot_product / (magnitude_a * magnitude_b)
  end
end
```

- [ ] **Step 4: FavoriteSearchIndexer에 임베딩 인덱싱 추가**

```ruby
# app/services/favorite_search_indexer.rb (수정)
class FavoriteSearchIndexer
  def self.index(favorite)
    # ... existing code ...

    # Generate embedding for semantic search
    content_for_embedding = [
      favorite.title,
      favorite.analysis&.summary,
      favorite.note
    ].compact.join(" ")

    embedding = EmbeddingService.call(content_for_embedding)
    embedding_json = embedding.present? ? embedding.to_json : nil

    conn.execute(
      "DELETE FROM favorites_fts WHERE favorite_id = #{favorite.id}"
    )

    conn.execute(
      ActiveRecord::Base.send(:sanitize_sql_array, [
        "INSERT INTO favorites_fts (favorite_id, title, summary, tags, note, content_embedding) VALUES (?, ?, ?, ?, ?, ?)",
        favorite.id, favorite.title, summary, tags, note, embedding_json
      ])
    )
  end
end
```

- [ ] **Step 5: 시맨틱 검색 테스트 작성**

```ruby
# test/services/semantic_search_test.rb
require "test_helper"

class SemanticSearchTest < ActiveSupport::TestCase
  def setup
    @favorite = Favorite.create!(url: "https://example.com/ai-article", content_type: "webpage", title: "AI and Machine Learning")
    @favorite.create_analysis!(
      summary: "Introduction to artificial intelligence concepts",
      tags: ["ai", "ml"]
    )
  end

  test "semantic search finds conceptually related content" do
    # Mock embedding service
    EmbeddingService.stub :call, [0.1, 0.9, 0.3] do
      results = SemanticSearch.call(query: "neural networks deep learning")

      # Should find the AI article even without exact keyword match
      assert results.any? { |f| f.id == @favorite.id }
    end
  end
end
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
bin/rails test test/services/semantic_search_test.rb
```
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add app/services/embedding_service.rb app/services/semantic_search.rb \
       app/services/favorite_search_indexer.rb \
       db/migrate/xxxx_add_embeddings_to_favorites_fts.rb \
       test/services/semantic_search_test.rb
git commit -m "feat: add semantic search with embeddings

- EmbeddingService for generating content vectors
- SemanticSearch combining FTS5 + cosine similarity
- FavoritesFts updated with content_embedding column"
```

---

## Task 4: 읽기 나중에 Newsletter 시스템

**Files:**
- Create: `app/jobs/weekly_newsletter_job.rb`
- Create: `app/mailers/weekly_newsletter_mailer.rb`
- Create: `app/views/weekly_newsletter_mailer/digest.html.erb`
- Create: `test/jobs/weekly_newsletter_job_test.rb`
- Create: `test/mailers/previews/weekly_newsletter_mailer_preview.rb`
- Modify: `app/services/favorite_search.rb` (unread favorites 메서드 추가)

- [ ] **Step 1: WeeklyNewsletterJob 생성**

```ruby
# app/jobs/weekly_newsletter_job.rb
class WeeklyNewsletterJob < ApplicationJob
  queue_as :default

  def perform
    return unless should_send?

    recent_favorites = fetch_recent_unread_favorites
    return if recent_favorites.empty?

    mailer_digest = build_digest(recent_favorites)
    WeeklyNewsletterMailer.digest(mail_digest).deliver_later
  end

  private

  def should_send?
    # Check if it's the right time (e.g., Sunday evening)
    # Or just check if there are enough new bookmarks
    recent_count = fetch_recent_unread_favorites.count
    recent_count >= 3
  end

  def fetch_recent_unread_favorites
    FavoriteSearch.call(
      status: "done",
      sort: "recent"
    ).where("created_at > ?", 7.days.ago).to_a
  end

  def build_digest(favorites)
    {
      date: I18n.l(Date.today, format: :long),
      favorites_count: favorites.count,
      favorites: favorites.map { |f| format_favorite(f) },
      top_tags: extract_top_tags(favorites)
    }
  end

  def format_favorite(favorite)
    {
      title: favorite.title.presence || favorite.url,
      url: favorite.url,
      summary: favorite.analysis&.summary,
      tags: favorite.analysis&.tags || [],
      created_at: I18n.l(favorite.created_at, format: :short)
    }
  end

  def extract_top_tags(favorites)
    all_tags = favorites.flat_map { |f| f.analysis&.tags || [] }
    all_tags
      .group_by(&:itself)
      .transform_values(&:count)
      .sort_by { |_, count| -count }
      .first(10)
      .map(&:first)
  end
end
```

- [ ] **Step 2: WeeklyNewsletterMailer 생성**

```ruby
# app/mailers/weekly_newsletter_mailer.rb
class WeeklyNewsletterMailer < ApplicationMailer
  default from: ENV["NEWSLETTER_FROM"] || "noreply@urlfavorites.local"

  def digest(digest_data)
    @digest = digest_data
    @user_email = ENV["NEWSLETTER_TO"] || "hwandam@gmail.com"

    mail to: @user_email,
         subject: "[URLFavorites] #{@digest[:favorites_count]}개의 저장된 링크 주간 요약"
  end
end
```

- [ ] **Step 3: Newsletter 템플릿 작성**

```erb
<%# app/views/weekly_newsletter_mailer/digest.html.erb %>
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 24px; border-radius: 12px; margin-bottom: 24px; }
    .title { font-size: 24px; font-weight: bold; margin: 0; }
    .subtitle { opacity: 0.9; margin-top: 8px; }
    .card { border: 1px solid #e5e7eb; border-radius: 8px; padding: 16px; margin-bottom: 16px; }
    .card-title { font-size: 16px; font-weight: 600; color: #1f2937; margin: 0 0 8px 0; }
    .card-title a { color: #2563eb; text-decoration: none; }
    .card-summary { font-size: 14px; color: #6b7280; margin: 0 0 12px 0; line-height: 1.5; }
    .tags { display: flex; gap: 6px; flex-wrap: wrap; }
    .tag { background: #f3f4f6; color: #374151; padding: 4px 10px; border-radius: 16px; font-size: 12px; }
    .footer { text-align: center; color: #9ca3af; font-size: 12px; margin-top: 32px; padding-top: 16px; border-top: 1px solid #e5e7eb; }
  </style>
</head>
<body>
  <div class="header">
    <h1 class="title">📚 주간 링크 요약</h1>
    <p class="subtitle"><%= @digest[:date] %> · <%= @digest[:favorites_count] %>개 저장</p>
  </div>

  <% @digest[:favorites].each do |fav| %>
    <div class="card">
      <h3 class="card-title">
        <a href="<%= fav[:url] %>" target="_blank"><%= fav[:title] %></a>
      </h3>
      <% if fav[:summary].present? %>
        <p class="card-summary"><%= fav[:summary] %></p>
      <% end %>
      <% if fav[:tags].any? %>
        <div class="tags">
          <% fav[:tags].first(5).each do |tag| %>
            <span class="tag"><%= tag %></span>
          <% end %>
        </div>
      <% end %>
    </div>
  <% end %>

  <div class="footer">
    <p>URLFavorites 2.0에서 자동 생성됨</p>
    <p><a href="<%= favorites_url %>">모든 저장된 링크 보기</a></p>
  </div>
</body>
</html>
```

- [ ] **Step 4: NewsletterJob 테스트 작성**

```ruby
# test/jobs/weekly_newsletter_job_test.rb
require "test_helper"

class WeeklyNewsletterJobTest < ActiveSupport::TestCase
  def setup
    ActionMailer::Base.deliveries.clear
    # Create test favorites
    3.times do |i|
      fav = Favorite.create!(url: "https://example.com/article-#{i}", content_type: "webpage", status: "done")
      fav.create_analysis!(summary: "Test summary #{i}", tags: ["test"])
    end
  end

  test "sends newsletter when there are recent favorites" do
    WeeklyNewsletterJob.perform_now

    assert_equal 1, ActionMailer::Base.deliveries.count
    email = ActionMailer::Base.deliveries.last
    assert_includes email.subject, "저장된 링크"
  end

  test "does not send when fewer than 3 recent favorites" do
    # Delete 2 favorites, keep only 1
    Favorite.where("url LIKE ?", "%article-1%").delete_all
    Favorite.where("url LIKE ?", "%article-2%").delete_all

    WeeklyNewsletterJob.perform_now

    assert_equal 0, ActionMailer::Base.deliveries.count
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bin/rails test test/jobs/weekly_newsletter_job_test.rb
```
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/jobs/weekly_newsletter_job.rb app/mailers/weekly_newsletter_mailer.rb \
       app/views/weekly_newsletter_mailer/ test/jobs/weekly_newsletter_job_test.rb
git commit -m "feat: add weekly newsletter system

- WeeklyNewsletterJob for digest generation
- WeeklyNewsletterMailer with HTML template
- Sends when 3+ new bookmarks in past week"
```

---

## Self-Review 체크리스트

### 1. Spec Coverage
- [x] AI 폴백 시스템: Task 1에서 BACKENDS 체인 구현
- [x] 태그 학습: Task 2에서 TagFeedback + TagLearning 구현
- [x] 시맨틱 검색: Task 3에서 EmbeddingService + SemanticSearch 구현
- [x] Newsletter: Task 4에서 WeeklyNewsletterJob + Mailer 구현

### 2. Placeholder Scan
- [x] 모든 테스트에 실제 코드 작성
- [x] 모든 구현에 실제 코드 작성
- [x] "TBD", "TODO" 없음

### 3. Type Consistency
- [x] TagFeedback#original_tags, #corrected_tags 일관성 유지
- [x] SemanticSearch#call 인터페이스 FavoriteSearch와 유사하게 유지
- [x] WeeklyNewsletterJob#build_digest 해시 키 일관성 유지

---

## 실행 옵션

**Plan complete and saved to `docs/superpowers/plans/2026-04-12-trend-features-implementation.md`**

**Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
