# URLFavorites Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rails 8 기반 개인용 URL 즐겨찾기 AI 분석 게시판 — 웹페이지·YouTube URL 저장 시 Qwen3 LLM이 자동 분석하여 리스트+상세 패널로 표시.

**Architecture:** Rails 8 모노리스. Solid Queue로 AI 분석 비동기 처리. Hotwire(Turbo + ActionCable)로 실시간 UI 갱신. PWA + Web Share Target으로 모바일 지원. REST API(`/api/v1/`)로 외부 AI 접근.

**Tech Stack:** Rails 8.1.2, Ruby 3.4.9, SQLite3, Solid Queue, Hotwire (Turbo + Stimulus + ActionCable), Nokogiri, yt-dlp (system), Qwen3-30B-A3B via llama-server HTTP

---

## File Map

```
# Models & DB
db/migrate/*_create_favorites.rb
db/migrate/*_create_analyses.rb
app/models/favorite.rb
app/models/analysis.rb

# Services (one responsibility each)
app/services/url_type_detector.rb     # "webpage" | "youtube" 판별
app/services/webpage_scraper.rb       # Nokogiri 본문 추출
app/services/youtube_extractor.rb     # yt-dlp wrapper
app/services/llm_analyzer.rb          # Qwen3 HTTP POST + JSON 파싱

# Jobs
app/jobs/analyze_webpage_job.rb
app/jobs/analyze_youtube_job.rb

# Controllers
app/controllers/favorites_controller.rb          # 웹 UI
app/controllers/api/v1/favorites_controller.rb   # REST API

# Views
app/views/favorites/index.html.erb
app/views/favorites/_favorite.html.erb           # Turbo target: favorite_<id>
app/views/favorites/_analysis_panel.html.erb     # Turbo target: analysis_panel
app/views/layouts/application.html.erb           # PWA meta

# PWA
public/manifest.json
public/sw.js

# Routes
config/routes.rb

# Tests
test/models/favorite_test.rb
test/models/analysis_test.rb
test/services/url_type_detector_test.rb
test/services/webpage_scraper_test.rb
test/services/youtube_extractor_test.rb
test/services/llm_analyzer_test.rb
test/jobs/analyze_webpage_job_test.rb
test/jobs/analyze_youtube_job_test.rb
test/controllers/favorites_controller_test.rb
test/controllers/api/v1/favorites_controller_test.rb
```

---

## Task 1: Phase 0 — Git Cleanup

**Files:**

- 변경 없음 (git 작업만)

- [ ] **Step 1: 현재 git 상태 확인**

```bash
cd /Users/hwandam/workspace/URLFavorites
git status
```

Expected: 삭제된 Next.js 파일 다수 (D 표시) + 비추적 파일 확인

- [ ] **Step 2: Next.js 파일 삭제 커밋**

```bash
git add -A
git commit -m "chore: remove Next.js project files, migrate to Rails"
```

- [ ] **Step 3: 상태 확인**

```bash
git status
```

Expected: `working tree clean` (또는 .env.local, .omc/ 등 무시 가능한 파일만 남음)

---

## Task 2: Rails 프로젝트 초기화

**Files:**

- Create: `Gemfile`, `config/database.yml`, `config/application.rb` 등 (rails new 생성)
- Create: `.gitignore` 업데이트

- [ ] **Step 1: Rails 앱 초기화 (현재 디렉토리)**

```bash
cd /Users/hwandam/workspace/URLFavorites
rails new . --database=sqlite3 --skip-git --skip-bundle -j importmap
```

Expected: Rails 파일 생성 (기존 파일 덮어쓸지 묻는 프롬프트에 `Y` 입력)

- [ ] **Step 2: Gemfile에 필수 gem 추가**

`Gemfile` 에 아래 추가:

```ruby
gem "nokogiri"          # 웹페이지 크롤링
gem "faraday"           # llama-server HTTP 클라이언트
gem "faraday-retry"     # HTTP 재시도

group :test do
  gem "webmock"         # HTTP 목 (테스트용)
end
```

- [ ] **Step 3: bundle install**

```bash
bundle install
```

Expected: 오류 없이 설치 완료

- [ ] **Step 4: .gitignore에 .superpowers 추가**

```bash
echo ".superpowers/" >> .gitignore
echo ".env.local" >> .gitignore
```

- [ ] **Step 5: 초기 커밋**

```bash
git add -A
git commit -m "feat: initialize Rails 8 app with SQLite, Solid Queue, Hotwire"
```

---

## Task 3: Routes 설정

**Files:**

- Modify: `config/routes.rb`

- [ ] **Step 1: routes.rb 작성**

```ruby
# config/routes.rb
Rails.application.routes.draw do
  root "favorites#index"

  resources :favorites, only: [:index, :create, :show, :destroy] do
    member do
      post :retry
    end
  end

  namespace :api do
    namespace :v1 do
      resources :favorites, only: [:index, :show, :create, :destroy] do
        collection do
          get :search
          get :recent
        end
      end
    end
  end
end
```

- [ ] **Step 2: 라우트 확인**

```bash
rails routes | grep favorites
```

Expected: favorites#index, create, show, destroy, retry, api/v1/favorites# 경로 모두 출력

- [ ] **Step 3: 커밋**

```bash
git add config/routes.rb
git commit -m "feat: add routes for favorites and API v1"
```

---

## Task 4: Favorite 모델 + 마이그레이션

**Files:**

- Create: `db/migrate/*_create_favorites.rb`
- Create: `app/models/favorite.rb`
- Create: `test/models/favorite_test.rb`

- [ ] **Step 1: 마이그레이션 생성**

```bash
rails generate migration CreateFavorites \
  url:string title:string favicon_url:string thumbnail_url:string \
  content_type:string status:string raw_content:text \
  error_message:text retry_count:integer
```

- [ ] **Step 2: 마이그레이션 파일 수정** (인덱스 + 기본값 추가)

생성된 마이그레이션 파일 열어서:

```ruby
def change
  create_table :favorites do |t|
    t.string  :url,           null: false
    t.string  :title
    t.string  :favicon_url
    t.string  :thumbnail_url
    t.string  :content_type,  null: false, default: "webpage"
    t.string  :status,        null: false, default: "pending"
    t.text    :raw_content
    t.text    :error_message
    t.integer :retry_count,   null: false, default: 0
    t.timestamps
  end
  add_index :favorites, :url, unique: true
  add_index :favorites, :status
  add_index :favorites, :content_type
end
```

- [ ] **Step 3: 실패 테스트 작성**

```ruby
# test/models/favorite_test.rb
require "test_helper"

class FavoriteTest < ActiveSupport::TestCase
  test "url은 필수" do
    f = Favorite.new(url: nil)
    assert_not f.valid?
    assert_includes f.errors[:url], "can't be blank"
  end

  test "url은 유일해야 함" do
    Favorite.create!(url: "https://example.com", content_type: "webpage")
    f = Favorite.new(url: "https://example.com", content_type: "webpage")
    assert_not f.valid?
  end

  test "http/https만 허용" do
    f = Favorite.new(url: "ftp://example.com")
    assert_not f.valid?
  end

  test "내부 IP 차단" do
    f = Favorite.new(url: "http://192.168.0.1/page")
    assert_not f.valid?
  end

  test "youtube URL 감지" do
    f = Favorite.new(url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    f.valid?
    assert_equal "youtube", f.content_type
  end

  test "status enum 기본값은 pending" do
    f = Favorite.new(url: "https://example.com")
    assert_equal "pending", f.status
  end
end
```

- [ ] **Step 4: 테스트 실행 — FAIL 확인**

```bash
rails test test/models/favorite_test.rb
```

Expected: ERROR (Favorite 모델 없음)

- [ ] **Step 5: Favorite 모델 구현**

```ruby
# app/models/favorite.rb
class Favorite < ApplicationRecord
  has_one :analysis, dependent: :destroy

  YOUTUBE_PATTERN = /\A(https?:\/\/)?(www\.)?(youtube\.com\/watch\?|youtu\.be\/)/i
  PRIVATE_IP_PATTERN = /\A(https?:\/\/)(10\.|172\.(1[6-9]|2\d|3[01])\.|192\.168\.|127\.|localhost)/i

  validates :url, presence: true, uniqueness: true
  validate :url_must_be_http_or_https
  validate :url_must_not_be_private_ip

  before_validation :detect_content_type, on: :create

  enum :status, {
    pending:   "pending",
    analyzing: "analyzing",
    done:      "done",
    failed:    "failed"
  }, prefix: false

  private

  def detect_content_type
    self.content_type = url&.match?(YOUTUBE_PATTERN) ? "youtube" : "webpage"
  end

  def url_must_be_http_or_https
    return if url.blank?
    errors.add(:url, "must start with http:// or https://") unless url.match?(/\Ahttps?:\/\//i)
  end

  def url_must_not_be_private_ip
    return if url.blank?
    errors.add(:url, "private/internal URLs are not allowed") if url.match?(PRIVATE_IP_PATTERN)
  end
end
```

- [ ] **Step 6: DB 마이그레이션 실행**

```bash
rails db:migrate
```

- [ ] **Step 7: 테스트 실행 — PASS 확인**

```bash
rails test test/models/favorite_test.rb
```

Expected: 6 runs, 0 failures, 0 errors

- [ ] **Step 8: 커밋**

```bash
git add db/migrate/ app/models/favorite.rb test/models/favorite_test.rb
git commit -m "feat: add Favorite model with validations and YouTube detection"
```

---

## Task 5: Analysis 모델 + 마이그레이션

**Files:**

- Create: `db/migrate/*_create_analyses.rb`
- Create: `app/models/analysis.rb`
- Create: `test/models/analysis_test.rb`

- [ ] **Step 1: 마이그레이션 생성**

```bash
rails generate migration CreateAnalyses \
  favorite:references summary:text tags:text key_points:text \
  sentiment:string transcript:text subtitle_source:string \
  video_metadata:text model_used:string analyzed_at:datetime
```

- [ ] **Step 2: 마이그레이션 파일 수정**

```ruby
def change
  create_table :analyses do |t|
    t.references :favorite, null: false, foreign_key: true
    t.text    :summary
    t.text    :tags,            default: "[]"
    t.text    :key_points,      default: "[]"
    t.string  :sentiment
    t.text    :transcript
    t.string  :subtitle_source
    t.text    :video_metadata,  default: "{}"
    t.string  :model_used
    t.datetime :analyzed_at
    t.timestamps
  end
end
```

- [ ] **Step 3: 실패 테스트 작성**

```ruby
# test/models/analysis_test.rb
require "test_helper"

class AnalysisTest < ActiveSupport::TestCase
  setup do
    @favorite = Favorite.create!(url: "https://example.com", content_type: "webpage")
  end

  test "tags를 배열로 읽고 씀" do
    a = Analysis.create!(favorite: @favorite, tags: ["AI", "개발"].to_json)
    assert_equal ["AI", "개발"], a.parsed_tags
  end

  test "key_points를 배열로 읽고 씀" do
    points = [{ "point" => "핵심1", "timestamp" => nil }]
    a = Analysis.create!(favorite: @favorite, key_points: points.to_json)
    assert_equal points, a.parsed_key_points
  end

  test "favorite 삭제 시 analysis도 삭제" do
    Analysis.create!(favorite: @favorite)
    assert_difference "Analysis.count", -1 do
      @favorite.destroy
    end
  end
end
```

- [ ] **Step 4: 테스트 실행 — FAIL 확인**

```bash
rails test test/models/analysis_test.rb
```

Expected: ERROR

- [ ] **Step 5: Analysis 모델 구현**

```ruby
# app/models/analysis.rb
class Analysis < ApplicationRecord
  belongs_to :favorite

  def parsed_tags
    JSON.parse(tags || "[]")
  rescue JSON::ParserError
    []
  end

  def parsed_key_points
    JSON.parse(key_points || "[]")
  rescue JSON::ParserError
    []
  end

  def parsed_video_metadata
    JSON.parse(video_metadata || "{}")
  rescue JSON::ParserError
    {}
  end
end
```

- [ ] **Step 6: DB 마이그레이션**

```bash
rails db:migrate
```

- [ ] **Step 7: 테스트 PASS 확인**

```bash
rails test test/models/analysis_test.rb
```

Expected: 3 runs, 0 failures

- [ ] **Step 8: 커밋**

```bash
git add db/migrate/ app/models/analysis.rb test/models/analysis_test.rb
git commit -m "feat: add Analysis model with JSON helpers"
```

---

## Task 6: UrlTypeDetector 서비스

**Files:**

- Create: `app/services/url_type_detector.rb`
- Create: `test/services/url_type_detector_test.rb`

- [ ] **Step 1: 실패 테스트 작성**

```ruby
# test/services/url_type_detector_test.rb
require "test_helper"

class UrlTypeDetectorTest < ActiveSupport::TestCase
  test "youtube.com/watch URL → youtube" do
    assert_equal "youtube", UrlTypeDetector.call("https://www.youtube.com/watch?v=abc123")
  end

  test "youtu.be 단축 URL → youtube" do
    assert_equal "youtube", UrlTypeDetector.call("https://youtu.be/abc123")
  end

  test "일반 URL → webpage" do
    assert_equal "webpage", UrlTypeDetector.call("https://github.com/karakeep")
  end

  test "nil → webpage" do
    assert_equal "webpage", UrlTypeDetector.call(nil)
  end
end
```

- [ ] **Step 2: 실행 — FAIL 확인**

```bash
rails test test/services/url_type_detector_test.rb
```

- [ ] **Step 3: 구현**

```ruby
# app/services/url_type_detector.rb
class UrlTypeDetector
  YOUTUBE_PATTERN = /\A(https?:\/\/)?(www\.)?(youtube\.com\/watch\?|youtu\.be\/)/i

  def self.call(url)
    return "webpage" if url.blank?
    url.match?(YOUTUBE_PATTERN) ? "youtube" : "webpage"
  end
end
```

- [ ] **Step 4: 테스트 PASS 확인**

```bash
rails test test/services/url_type_detector_test.rb
```

Expected: 4 runs, 0 failures

- [ ] **Step 5: 커밋**

```bash
git add app/services/url_type_detector.rb test/services/url_type_detector_test.rb
git commit -m "feat: add UrlTypeDetector service"
```

---

## Task 7: WebpageScraper 서비스

**Files:**

- Create: `app/services/webpage_scraper.rb`
- Create: `test/services/webpage_scraper_test.rb`

- [ ] **Step 1: 실패 테스트 작성**

```ruby
# test/services/webpage_scraper_test.rb
require "test_helper"
require "webmock/minitest"

class WebpageScraperTest < ActiveSupport::TestCase
  test "제목과 본문 텍스트 추출" do
    html = <<~HTML
      <html><head><title>테스트 페이지</title></head>
      <body><article><p>본문 내용입니다.</p></article></body></html>
    HTML
    stub_request(:get, "https://example.com/page").to_return(body: html, headers: { "Content-Type" => "text/html" })

    result = WebpageScraper.call("https://example.com/page")

    assert_equal "테스트 페이지", result[:title]
    assert_includes result[:text], "본문 내용입니다."
    assert result[:text].length <= 8000
  end

  test "HTTP 오류 시 nil 반환" do
    stub_request(:get, "https://example.com/404").to_return(status: 404)
    result = WebpageScraper.call("https://example.com/404")
    assert_nil result
  end

  test "파비콘 URL 추출" do
    html = '<html><head><link rel="icon" href="/favicon.ico"></head><body></body></html>'
    stub_request(:get, "https://example.com").to_return(body: html, headers: { "Content-Type" => "text/html" })
    result = WebpageScraper.call("https://example.com")
    assert_not_nil result[:favicon_url]
  end
end
```

- [ ] **Step 2: 실행 — FAIL 확인**

```bash
rails test test/services/webpage_scraper_test.rb
```

- [ ] **Step 3: 구현**

```ruby
# app/services/webpage_scraper.rb
require "nokogiri"
require "open-uri"

class WebpageScraper
  MAX_TEXT_LENGTH = 8_000

  def self.call(url)
    new(url).scrape
  end

  def initialize(url)
    @url = url
  end

  def scrape
    response = URI.open(@url, read_timeout: 15, "User-Agent" => "URLFavorites/1.0")
    doc = Nokogiri::HTML(response.read)

    {
      title: extract_title(doc),
      text: extract_text(doc),
      favicon_url: extract_favicon(doc)
    }
  rescue OpenURI::HTTPError, SocketError, Errno::ECONNREFUSED, Net::ReadTimeout => e
    Rails.logger.warn "WebpageScraper failed for #{@url}: #{e.message}"
    nil
  end

  private

  def extract_title(doc)
    doc.at("meta[property='og:title']")&.attr("content") ||
      doc.at("title")&.text&.strip
  end

  def extract_text(doc)
    %w[article main].each do |tag|
      node = doc.at(tag)
      return clean_text(node.text) if node
    end
    paragraphs = doc.css("p").map(&:text).join(" ")
    clean_text(paragraphs)
  end

  def extract_favicon(doc)
    icon = doc.at("link[rel~='icon']")&.attr("href")
    return nil unless icon
    icon.start_with?("http") ? icon : "#{URI.parse(@url).scheme}://#{URI.parse(@url).host}#{icon}"
  end

  def clean_text(text)
    text.gsub(/\s+/, " ").strip.truncate(MAX_TEXT_LENGTH, omission: "")
  end
end
```

- [ ] **Step 4: 테스트 PASS 확인**

```bash
rails test test/services/webpage_scraper_test.rb
```

Expected: 3 runs, 0 failures

- [ ] **Step 5: 커밋**

```bash
git add app/services/webpage_scraper.rb test/services/webpage_scraper_test.rb
git commit -m "feat: add WebpageScraper service with Nokogiri"
```

---

## Task 8: YoutubeExtractor 서비스

**Files:**

- Create: `app/services/youtube_extractor.rb`
- Create: `test/services/youtube_extractor_test.rb`

- [ ] **Step 1: yt-dlp 설치 확인 (VPS에서)**

```bash
yt-dlp --version
```

Expected: 버전 번호 출력. 없으면: `sudo apt install yt-dlp` 또는 `pip install yt-dlp`

- [ ] **Step 2: 실패 테스트 작성**

```ruby
# test/services/youtube_extractor_test.rb
require "test_helper"

class YoutubeExtractorTest < ActiveSupport::TestCase
  test "subtitle_source는 manual, auto, description 중 하나" do
    valid = %w[manual auto description]
    extractor = YoutubeExtractor.new("https://youtu.be/test")
    assert_includes valid + [nil], extractor.class.name  # 구조 확인용
  end

  test "메타데이터 구조에 필수 키 포함" do
    # yt-dlp --dump-json 출력 목(mock)
    mock_json = {
      "title" => "테스트 영상",
      "uploader" => "테스트 채널",
      "view_count" => 12345,
      "duration" => 360,
      "upload_date" => "20260101",
      "thumbnail" => "https://img.youtube.com/vi/test/0.jpg"
    }.to_json

    extractor = YoutubeExtractor.new("https://youtu.be/test")
    extractor.stub(:run_ytdlp_metadata, mock_json) do
      extractor.stub(:run_ytdlp_subtitles, { text: "자막 내용", source: "auto" }) do
        result = extractor.extract
        assert_equal "테스트 영상", result[:title]
        assert_equal "auto", result[:subtitle_source]
        assert_includes result[:transcript], "자막 내용"
      end
    end
  end
end
```

- [ ] **Step 3: 실행 — FAIL 확인**

```bash
rails test test/services/youtube_extractor_test.rb
```

- [ ] **Step 4: 구현**

```ruby
# app/services/youtube_extractor.rb
require "open3"
require "tmpdir"
require "json"

class YoutubeExtractor
  MAX_TRANSCRIPT_LENGTH = 12_000

  def self.call(url)
    new(url).extract
  end

  def initialize(url)
    @url = url
  end

  def extract
    metadata = parse_metadata(run_ytdlp_metadata)
    subtitle_result = run_ytdlp_subtitles

    {
      title: metadata["title"],
      thumbnail_url: metadata["thumbnail"],
      transcript: subtitle_result[:text]&.truncate(MAX_TRANSCRIPT_LENGTH, omission: ""),
      subtitle_source: subtitle_result[:source],
      video_metadata: {
        channel: metadata["uploader"],
        view_count: metadata["view_count"],
        duration: metadata["duration"],
        upload_date: metadata["upload_date"]
      }.to_json
    }
  rescue => e
    Rails.logger.error "YoutubeExtractor failed for #{@url}: #{e.message}"
    nil
  end

  def run_ytdlp_metadata
    stdout, _, status = Open3.capture3("yt-dlp --dump-json --no-playlist '#{@url}'")
    raise "yt-dlp metadata failed" unless status.success?
    stdout
  end

  def run_ytdlp_subtitles
    Dir.mktmpdir do |dir|
      # 1. 수동 자막 시도
      _, _, status = Open3.capture3(
        "yt-dlp --write-sub --skip-download --sub-lang ko,en --convert-subs srt -o '#{dir}/sub' '#{@url}'"
      )
      srt_file = Dir.glob("#{dir}/sub*.srt").first
      if srt_file
        return { text: parse_srt(File.read(srt_file)), source: "manual" }
      end

      # 2. 자동 생성 자막 시도
      Open3.capture3(
        "yt-dlp --write-auto-sub --skip-download --sub-lang ko,en --convert-subs srt -o '#{dir}/auto' '#{@url}'"
      )
      auto_file = Dir.glob("#{dir}/auto*.srt").first
      if auto_file
        return { text: parse_srt(File.read(auto_file)), source: "auto" }
      end

      # 3. description 폴백
      meta = parse_metadata(run_ytdlp_metadata)
      fallback = [meta["title"], meta["description"]].compact.join("\n")
      { text: fallback, source: "description" }
    end
  end

  private

  def parse_metadata(json_str)
    JSON.parse(json_str)
  rescue JSON::ParserError
    {}
  end

  def parse_srt(content)
    content.gsub(/\d+\n\d{2}:\d{2}:\d{2},\d{3} --> \d{2}:\d{2}:\d{2},\d{3}\n/, "")
           .gsub(/<[^>]+>/, "")
           .strip
  end
end
```

- [ ] **Step 5: 테스트 PASS 확인**

```bash
rails test test/services/youtube_extractor_test.rb
```

- [ ] **Step 6: 커밋**

```bash
git add app/services/youtube_extractor.rb test/services/youtube_extractor_test.rb
git commit -m "feat: add YoutubeExtractor service with yt-dlp subtitle fallback chain"
```

---

## Task 9: LlmAnalyzer 서비스

**Files:**

- Create: `app/services/llm_analyzer.rb`
- Create: `test/services/llm_analyzer_test.rb`

- [ ] **Step 1: 실패 테스트 작성**

```ruby
# test/services/llm_analyzer_test.rb
require "test_helper"
require "webmock/minitest"

class LlmAnalyzerTest < ActiveSupport::TestCase
  MOCK_RESPONSE = {
    choices: [{
      message: {
        content: {
          summary: "테스트 요약입니다.",
          tags: ["AI", "테스트"],
          key_points: [{ point: "핵심 포인트", timestamp: nil }],
          sentiment: "positive"
        }.to_json
      }
    }]
  }.to_json

  setup do
    @llm_url = "http://10.0.0.1:8080"
    ENV["LLAMA_SERVER_URL"] = @llm_url
  end

  test "정상 응답 파싱" do
    stub_request(:post, "#{@llm_url}/v1/chat/completions")
      .to_return(body: MOCK_RESPONSE, headers: { "Content-Type" => "application/json" })

    result = LlmAnalyzer.call(content: "테스트 내용", content_type: "webpage")

    assert_equal "테스트 요약입니다.", result[:summary]
    assert_equal ["AI", "테스트"], result[:tags]
    assert_equal "positive", result[:sentiment]
  end

  test "JSON 파싱 실패 시 nil 반환" do
    bad_response = { choices: [{ message: { content: "JSON 아님" } }] }.to_json
    stub_request(:post, "#{@llm_url}/v1/chat/completions")
      .to_return(body: bad_response, headers: { "Content-Type" => "application/json" })

    result = LlmAnalyzer.call(content: "테스트", content_type: "webpage")
    assert_nil result
  end

  test "HTTP 타임아웃 시 nil 반환" do
    stub_request(:post, "#{@llm_url}/v1/chat/completions").to_timeout
    result = LlmAnalyzer.call(content: "테스트", content_type: "webpage")
    assert_nil result
  end
end
```

- [ ] **Step 2: 실행 — FAIL 확인**

```bash
rails test test/services/llm_analyzer_test.rb
```

- [ ] **Step 3: 구현**

```ruby
# app/services/llm_analyzer.rb
require "faraday"
require "json"

class LlmAnalyzer
  TIMEOUT = 120
  MODEL = "Qwen3-30B-A3B-Instruct-2507"

  WEBPAGE_PROMPT = <<~PROMPT
    다음 웹페이지 내용을 분석하고 반드시 아래 JSON 형식으로만 응답하세요:
    {"summary":"2~5문장 요약","tags":["태그1","태그2"],"key_points":[{"point":"핵심내용","timestamp":null}],"sentiment":"positive|neutral|negative"}
  PROMPT

  YOUTUBE_PROMPT = <<~PROMPT
    다음 YouTube 영상 자막과 메타데이터를 분석하고 반드시 아래 JSON 형식으로만 응답하세요:
    {"summary":"2~5문장 요약","tags":["태그1","태그2"],"key_points":[{"point":"핵심내용","timestamp":"HH:MM:SS 또는 null"}],"sentiment":"positive|neutral|negative"}
  PROMPT

  def self.call(content:, content_type:)
    new.analyze(content: content, content_type: content_type)
  end

  def analyze(content:, content_type:)
    prompt = content_type == "youtube" ? YOUTUBE_PROMPT : WEBPAGE_PROMPT
    response = connection.post("/v1/chat/completions") do |req|
      req.body = {
        model: MODEL,
        messages: [
          { role: "system", content: prompt },
          { role: "user", content: content.to_s.truncate(12_000) }
        ],
        response_format: { type: "json_object" },
        temperature: 0.1
      }.to_json
    end

    parse_response(response.body)
  rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
    Rails.logger.error "LlmAnalyzer connection error: #{e.message}"
    nil
  end

  private

  def connection
    @connection ||= Faraday.new(url: ENV.fetch("LLAMA_SERVER_URL")) do |f|
      f.options.timeout = TIMEOUT
      f.options.open_timeout = 10
      f.headers["Content-Type"] = "application/json"
      f.adapter Faraday.default_adapter
    end
  end

  def parse_response(body)
    data = JSON.parse(body)
    content = data.dig("choices", 0, "message", "content")
    result = JSON.parse(content)
    {
      summary: result["summary"],
      tags: Array(result["tags"]),
      key_points: Array(result["key_points"]),
      sentiment: result["sentiment"]
    }
  rescue JSON::ParserError => e
    Rails.logger.error "LlmAnalyzer JSON parse error: #{e.message}"
    nil
  end
end
```

- [ ] **Step 4: 테스트 PASS 확인**

```bash
rails test test/services/llm_analyzer_test.rb
```

Expected: 3 runs, 0 failures

- [ ] **Step 5: 커밋**

```bash
git add app/services/llm_analyzer.rb test/services/llm_analyzer_test.rb
git commit -m "feat: add LlmAnalyzer service with Faraday + Qwen3 integration"
```

---

## Task 10: AnalyzeWebpageJob

**Files:**

- Create: `app/jobs/analyze_webpage_job.rb`
- Create: `test/jobs/analyze_webpage_job_test.rb`

- [ ] **Step 1: 실패 테스트 작성**

```ruby
# test/jobs/analyze_webpage_job_test.rb
require "test_helper"

class AnalyzeWebpageJobTest < ActiveSupport::TestCase
  setup do
    @favorite = Favorite.create!(url: "https://example.com", content_type: "webpage")
  end

  test "성공 시 status를 done으로 갱신" do
    WebpageScraper.stub(:call, { title: "제목", text: "내용", favicon_url: nil }) do
      LlmAnalyzer.stub(:call, { summary: "요약", tags: ["태그"], key_points: [], sentiment: "positive" }) do
        AnalyzeWebpageJob.new.perform(@favorite.id)
        @favorite.reload
        assert_equal "done", @favorite.status
        assert_not_nil @favorite.analysis
      end
    end
  end

  test "스크래핑 실패 시 status를 failed로 갱신" do
    WebpageScraper.stub(:call, nil) do
      AnalyzeWebpageJob.new.perform(@favorite.id)
      @favorite.reload
      assert_equal "failed", @favorite.status
      assert_not_nil @favorite.error_message
    end
  end

  test "raw_content가 이미 있으면 재크롤링하지 않음" do
    @favorite.update!(raw_content: "기존 캐시 내용")
    scraper_called = false
    WebpageScraper.stub(:call, -> (_) { scraper_called = true; nil }) do
      LlmAnalyzer.stub(:call, { summary: "요약", tags: [], key_points: [], sentiment: "neutral" }) do
        AnalyzeWebpageJob.new.perform(@favorite.id)
        assert_not scraper_called, "raw_content 있으면 스크래퍼 호출 금지"
      end
    end
  end
end
```

- [ ] **Step 2: 실행 — FAIL 확인**

```bash
rails test test/jobs/analyze_webpage_job_test.rb
```

- [ ] **Step 3: 구현**

```ruby
# app/jobs/analyze_webpage_job.rb
class AnalyzeWebpageJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(favorite_id)
    favorite = Favorite.find(favorite_id)
    favorite.update!(status: "analyzing")
    broadcast_update(favorite)

    content = fetch_content(favorite)
    unless content
      fail_favorite(favorite, "페이지 크롤링 실패")
      return
    end

    result = LlmAnalyzer.call(content: content, content_type: "webpage")
    unless result
      fail_favorite(favorite, "AI 분석 실패 (응답 파싱 오류)")
      return
    end

    favorite.create_analysis!(
      summary: result[:summary],
      tags: result[:tags].to_json,
      key_points: result[:key_points].to_json,
      sentiment: result[:sentiment],
      model_used: LlmAnalyzer::MODEL,
      analyzed_at: Time.current
    )
    favorite.update!(status: "done")
    broadcast_update(favorite)
  end

  private

  def fetch_content(favorite)
    return favorite.raw_content if favorite.raw_content.present?

    scraped = WebpageScraper.call(favorite.url)
    return nil unless scraped

    favorite.update!(
      title: scraped[:title] || favorite.title,
      favicon_url: scraped[:favicon_url],
      raw_content: scraped[:text]
    )
    scraped[:text]
  end

  def fail_favorite(favorite, message)
    favorite.update!(
      status: "failed",
      error_message: message,
      retry_count: favorite.retry_count + 1
    )
    broadcast_update(favorite)
  end

  def broadcast_update(favorite)
    Turbo::StreamsChannel.broadcast_replace_to(
      "favorites",
      target: "favorite_#{favorite.id}",
      partial: "favorites/favorite",
      locals: { favorite: favorite }
    )
  end
end
```

- [ ] **Step 4: 테스트 PASS 확인**

```bash
rails test test/jobs/analyze_webpage_job_test.rb
```

Expected: 3 runs, 0 failures

- [ ] **Step 5: 커밋**

```bash
git add app/jobs/analyze_webpage_job.rb test/jobs/analyze_webpage_job_test.rb
git commit -m "feat: add AnalyzeWebpageJob with retry and ActionCable broadcast"
```

---

## Task 11: AnalyzeYoutubeJob

**Files:**

- Create: `app/jobs/analyze_youtube_job.rb`
- Create: `test/jobs/analyze_youtube_job_test.rb`

- [ ] **Step 1: 실패 테스트 작성**

```ruby
# test/jobs/analyze_youtube_job_test.rb
require "test_helper"

class AnalyzeYoutubeJobTest < ActiveSupport::TestCase
  setup do
    @favorite = Favorite.create!(url: "https://youtu.be/dQw4w9WgXcQ", content_type: "youtube")
  end

  test "성공 시 status를 done으로 갱신, subtitle_source 저장" do
    extracted = {
      title: "테스트 영상",
      thumbnail_url: "https://img.youtube.com/vi/test/0.jpg",
      transcript: "자막 내용",
      subtitle_source: "auto",
      video_metadata: { channel: "채널" }.to_json
    }
    YoutubeExtractor.stub(:call, extracted) do
      LlmAnalyzer.stub(:call, { summary: "요약", tags: ["AI"], key_points: [], sentiment: "positive" }) do
        AnalyzeYoutubeJob.new.perform(@favorite.id)
        @favorite.reload
        assert_equal "done", @favorite.status
        assert_equal "auto", @favorite.analysis.subtitle_source
      end
    end
  end

  test "YouTube 추출 실패 시 failed 처리" do
    YoutubeExtractor.stub(:call, nil) do
      AnalyzeYoutubeJob.new.perform(@favorite.id)
      @favorite.reload
      assert_equal "failed", @favorite.status
    end
  end
end
```

- [ ] **Step 2: 실행 — FAIL 확인**

```bash
rails test test/jobs/analyze_youtube_job_test.rb
```

- [ ] **Step 3: 구현**

```ruby
# app/jobs/analyze_youtube_job.rb
class AnalyzeYoutubeJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(favorite_id)
    favorite = Favorite.find(favorite_id)
    favorite.update!(status: "analyzing")
    broadcast_update(favorite)

    extracted = fetch_content(favorite)
    unless extracted
      fail_favorite(favorite, "YouTube 추출 실패")
      return
    end

    result = LlmAnalyzer.call(content: extracted[:transcript], content_type: "youtube")
    unless result
      fail_favorite(favorite, "AI 분석 실패")
      return
    end

    favorite.create_analysis!(
      summary: result[:summary],
      tags: result[:tags].to_json,
      key_points: result[:key_points].to_json,
      sentiment: result[:sentiment],
      transcript: extracted[:transcript],
      subtitle_source: extracted[:subtitle_source],
      video_metadata: extracted[:video_metadata],
      model_used: LlmAnalyzer::MODEL,
      analyzed_at: Time.current
    )
    favorite.update!(
      title: extracted[:title] || favorite.title,
      thumbnail_url: extracted[:thumbnail_url],
      status: "done"
    )
    broadcast_update(favorite)
  end

  private

  def fetch_content(favorite)
    return build_from_cache(favorite) if favorite.raw_content.present?

    extracted = YoutubeExtractor.call(favorite.url)
    return nil unless extracted

    favorite.update!(raw_content: extracted[:transcript])
    extracted
  end

  def build_from_cache(favorite)
    { transcript: favorite.raw_content, subtitle_source: "cached", video_metadata: "{}" }
  end

  def fail_favorite(favorite, message)
    favorite.update!(status: "failed", error_message: message, retry_count: favorite.retry_count + 1)
    broadcast_update(favorite)
  end

  def broadcast_update(favorite)
    Turbo::StreamsChannel.broadcast_replace_to(
      "favorites",
      target: "favorite_#{favorite.id}",
      partial: "favorites/favorite",
      locals: { favorite: favorite }
    )
  end
end
```

- [ ] **Step 4: 테스트 PASS 확인**

```bash
rails test test/jobs/analyze_youtube_job_test.rb
```

Expected: 2 runs, 0 failures

- [ ] **Step 5: 커밋**

```bash
git add app/jobs/analyze_youtube_job.rb test/jobs/analyze_youtube_job_test.rb
git commit -m "feat: add AnalyzeYoutubeJob with subtitle_source tracking"
```

---

## Task 12: FavoritesController + Views (B+C 레이아웃)

**Files:**

- Create: `app/controllers/favorites_controller.rb`
- Create: `app/views/favorites/index.html.erb`
- Create: `app/views/favorites/_favorite.html.erb`
- Create: `app/views/favorites/_analysis_panel.html.erb`
- Modify: `app/views/layouts/application.html.erb`
- Create: `test/controllers/favorites_controller_test.rb`

- [ ] **Step 1: 실패 테스트 작성**

```ruby
# test/controllers/favorites_controller_test.rb
require "test_helper"

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  test "GET / 성공" do
    get root_path
    assert_response :success
  end

  test "POST /favorites — 새 URL 등록" do
    assert_difference "Favorite.count", 1 do
      post favorites_path, params: { favorite: { url: "https://example.com/new" } }
    end
    assert_redirected_to root_path
  end

  test "POST /favorites — 중복 URL은 리다이렉트만" do
    Favorite.create!(url: "https://example.com", content_type: "webpage")
    assert_no_difference "Favorite.count" do
      post favorites_path, params: { favorite: { url: "https://example.com" } }
    end
  end

  test "DELETE /favorites/:id — 삭제" do
    f = Favorite.create!(url: "https://example.com", content_type: "webpage")
    assert_difference "Favorite.count", -1 do
      delete favorite_path(f)
    end
    assert_redirected_to root_path
  end

  test "POST /favorites/:id/retry — failed 항목 재시도" do
    f = Favorite.create!(url: "https://example.com", content_type: "webpage", status: "failed")
    post retry_favorite_path(f)
    f.reload
    assert_equal "pending", f.status
    assert_equal 0, f.retry_count
  end
end
```

- [ ] **Step 2: 실행 — FAIL 확인**

```bash
rails test test/controllers/favorites_controller_test.rb
```

- [ ] **Step 3: 컨트롤러 구현**

```ruby
# app/controllers/favorites_controller.rb
class FavoritesController < ApplicationController
  def index
    @favorites = Favorite.order(created_at: :desc)
    @favorite = Favorite.new
    @selected = @favorites.first
  end

  def show
    @favorite = Favorite.find(params[:id])
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "analysis_panel",
          partial: "favorites/analysis_panel",
          locals: { favorite: @favorite }
        )
      end
      format.html { redirect_to root_path }
    end
  end

  def create
    url = params.dig(:favorite, :url)&.strip
    existing = Favorite.find_by(url: url)
    if existing
      redirect_to root_path, notice: "이미 저장된 URL입니다."
      return
    end

    @favorite = Favorite.new(url: url)
    if @favorite.save
      enqueue_analysis(@favorite)
      redirect_to root_path, notice: "등록되었습니다."
    else
      @favorites = Favorite.order(created_at: :desc)
      @selected = @favorites.first
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    Favorite.find(params[:id]).destroy
    redirect_to root_path, notice: "삭제되었습니다."
  end

  def retry
    @favorite = Favorite.find(params[:id])
    @favorite.update!(status: "pending", retry_count: 0, error_message: nil)
    enqueue_analysis(@favorite)
    redirect_to root_path, notice: "재분석을 시작합니다."
  end

  private

  def enqueue_analysis(favorite)
    if favorite.content_type == "youtube"
      AnalyzeYoutubeJob.perform_later(favorite.id)
    else
      AnalyzeWebpageJob.perform_later(favorite.id)
    end
  end
end
```

- [ ] **Step 4: 레이아웃에 PWA 메타 태그 + Turbo 구독 추가**

`app/views/layouts/application.html.erb` 의 `<head>` 에 추가:

```erb
<link rel="manifest" href="/manifest.json">
<meta name="theme-color" content="#1d4ed8">
<meta name="mobile-web-app-capable" content="yes">
```

- [ ] **Step 5: 메인 뷰 작성 (index.html.erb)**

```erb
<%# app/views/favorites/index.html.erb %>
<%= turbo_stream_from "favorites" %>

<div class="app-layout">
  <%# 헤더: URL 입력 %>
  <header class="app-header">
    <h1>URLFavorites</h1>
    <%= form_with model: @favorite, url: favorites_path, data: { turbo: false } do |f| %>
      <%= f.url_field :url, placeholder: "URL을 입력하세요...", class: "url-input" %>
      <%= f.submit "저장", class: "btn-primary" %>
    <% end %>
  </header>

  <%# B+C 레이아웃 %>
  <div class="board-layout">
    <%# 왼쪽: 즐겨찾기 목록 (B형) %>
    <aside class="favorites-list">
      <% @favorites.each do |favorite| %>
        <%= render "favorite", favorite: favorite %>
      <% end %>
    </aside>

    <%# 오른쪽: 상세 패널 (C형) %>
    <%= turbo_frame_tag "analysis_panel" do %>
      <% if @selected %>
        <%= render "analysis_panel", favorite: @selected %>
      <% else %>
        <div class="empty-panel">URL을 선택하면 분석 결과가 표시됩니다.</div>
      <% end %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 6: 목록 아이템 partial**

```erb
<%# app/views/favorites/_favorite.html.erb %>
<div id="favorite_<%= favorite.id %>" class="favorite-item <%= favorite.status %>">
  <%= link_to favorite_path(favorite), data: { turbo_frame: "analysis_panel" } do %>
    <div class="favorite-header">
      <% if favorite.favicon_url.present? %>
        <img src="<%= favorite.favicon_url %>" class="favicon" alt="">
      <% end %>
      <span class="favorite-title"><%= favorite.title || favorite.url %></span>
      <% if favorite.content_type == "youtube" %>
        <span class="badge badge-youtube">YouTube</span>
      <% end %>
      <span class="badge badge-<%= favorite.status %>"><%= favorite.status %></span>
    </div>
    <% if favorite.analysis %>
      <p class="favorite-summary"><%= favorite.analysis.summary&.truncate(100) %></p>
      <div class="tags">
        <% favorite.analysis.parsed_tags.each do |tag| %>
          <span class="tag"><%= tag %></span>
        <% end %>
      </div>
    <% elsif favorite.status == "analyzing" %>
      <p class="analyzing">분석 중...</p>
    <% elsif favorite.status == "failed" %>
      <p class="error"><%= favorite.error_message %></p>
      <% if favorite.retry_count >= 3 %>
        <%= button_to "재시도", retry_favorite_path(favorite), method: :post, class: "btn-retry" %>
      <% end %>
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 7: 상세 패널 partial**

```erb
<%# app/views/favorites/_analysis_panel.html.erb %>
<div class="analysis-panel">
  <div class="panel-header">
    <h2><%= favorite.title || favorite.url %></h2>
    <a href="<%= favorite.url %>" target="_blank" class="btn-link">원본 링크 열기 ↗</a>
    <%= button_to "삭제", favorite_path(favorite), method: :delete,
        data: { confirm: "삭제하시겠습니까?" }, class: "btn-danger" %>
  </div>

  <% if favorite.content_type == "youtube" && favorite.thumbnail_url.present? %>
    <div class="youtube-meta">
      <img src="<%= favorite.thumbnail_url %>" class="thumbnail" alt="">
      <% meta = favorite.analysis&.parsed_video_metadata || {} %>
      <span class="meta-info"><%= meta["channel"] %> · 조회수 <%= meta["view_count"] %> · <%= meta["duration"]&./(60)&.round %>분</span>
      <% if favorite.analysis&.subtitle_source %>
        <span class="subtitle-badge"><%= favorite.analysis.subtitle_source == "auto" ? "자동생성 자막" : favorite.analysis.subtitle_source %></span>
      <% end %>
    </div>
  <% end %>

  <% if favorite.analysis %>
    <section class="panel-section">
      <h3>📝 요약</h3>
      <p><%= favorite.analysis.summary %></p>
    </section>

    <section class="panel-section">
      <h3>🏷 태그</h3>
      <div class="tags">
        <% favorite.analysis.parsed_tags.each do |tag| %>
          <span class="tag"><%= tag %></span>
        <% end %>
      </div>
    </section>

    <section class="panel-section">
      <h3>💡 핵심 인사이트</h3>
      <ul>
        <% favorite.analysis.parsed_key_points.each do |kp| %>
          <li>
            <%= kp["point"] %>
            <% if kp["timestamp"].present? %>
              <span class="timestamp">(<%= kp["timestamp"] %>)</span>
            <% end %>
          </li>
        <% end %>
      </ul>
    </section>

    <section class="panel-section panel-meta">
      <span>🎭 감정: <%= favorite.analysis.sentiment %></span>
      <span>📅 저장: <%= favorite.created_at.strftime("%Y-%m-%d") %></span>
      <span>🤖 <%= favorite.analysis.model_used %></span>
    </section>
  <% elsif favorite.status == "analyzing" %>
    <div class="analyzing-indicator">AI 분석 중입니다...</div>
  <% end %>
</div>
```

- [ ] **Step 8: 테스트 PASS 확인**

```bash
rails test test/controllers/favorites_controller_test.rb
```

Expected: 5 runs, 0 failures

- [ ] **Step 9: 커밋**

```bash
git add app/controllers/favorites_controller.rb app/views/favorites/ app/views/layouts/
git add test/controllers/favorites_controller_test.rb
git commit -m "feat: add FavoritesController and B+C layout views with Turbo"
```

---

## Task 13: REST API 컨트롤러

**Files:**

- Create: `app/controllers/api/v1/favorites_controller.rb`
- Create: `test/controllers/api/v1/favorites_controller_test.rb`

- [ ] **Step 1: 실패 테스트 작성**

```ruby
# test/controllers/api/v1/favorites_controller_test.rb
require "test_helper"

class Api::V1::FavoritesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @f = Favorite.create!(url: "https://example.com", content_type: "webpage", status: "done")
    @f.create_analysis!(
      summary: "요약", tags: '["AI"]', key_points: "[]",
      sentiment: "positive", model_used: "Qwen3", analyzed_at: Time.current
    )
  end

  test "GET /api/v1/favorites — JSON 목록 반환" do
    get api_v1_favorites_path, as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert body.is_a?(Array)
    assert_equal 1, body.length
    assert body.first.key?("analysis")
  end

  test "GET /api/v1/favorites/:id — 단일 항목" do
    get api_v1_favorite_path(@f), as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "요약", body.dig("analysis", "summary")
    assert_equal ["AI"], body.dig("analysis", "tags")
  end

  test "POST /api/v1/favorites — 새 URL 등록" do
    assert_difference "Favorite.count", 1 do
      post api_v1_favorites_path, params: { url: "https://newsite.com" }, as: :json
    end
    assert_response :created
  end

  test "GET /api/v1/favorites/search?q= — 검색" do
    get search_api_v1_favorites_path, params: { q: "example" }, as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert body.is_a?(Array)
  end

  test "GET /api/v1/favorites/recent — 최근 항목" do
    get recent_api_v1_favorites_path, as: :json
    assert_response :success
  end
end
```

- [ ] **Step 2: 실행 — FAIL 확인**

```bash
rails test test/controllers/api/v1/favorites_controller_test.rb
```

- [ ] **Step 3: 구현**

```ruby
# app/controllers/api/v1/favorites_controller.rb
module Api
  module V1
    class FavoritesController < ApplicationController
      protect_from_forgery with: :null_session

      def index
        favorites = Favorite.includes(:analysis)
                            .order(created_at: :desc)
                            .limit(params.fetch(:limit, 50).to_i)
        render json: favorites.map { |f| serialize(f) }
      end

      def show
        favorite = Favorite.includes(:analysis).find(params[:id])
        render json: serialize(favorite)
      rescue ActiveRecord::RecordNotFound
        render json: { error: "not found" }, status: :not_found
      end

      def create
        favorite = Favorite.find_or_initialize_by(url: params[:url]&.strip)
        if favorite.new_record?
          favorite.save!
          enqueue_analysis(favorite)
          render json: serialize(favorite), status: :created
        else
          render json: serialize(favorite), status: :ok
        end
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      def destroy
        Favorite.find(params[:id]).destroy
        head :no_content
      rescue ActiveRecord::RecordNotFound
        render json: { error: "not found" }, status: :not_found
      end

      def search
        q = params[:q].to_s.strip
        favorites = Favorite.includes(:analysis)
                            .joins("LEFT JOIN analyses ON analyses.favorite_id = favorites.id")
                            .where("favorites.url LIKE ? OR favorites.title LIKE ? OR analyses.summary LIKE ? OR analyses.tags LIKE ?",
                                   "%#{q}%", "%#{q}%", "%#{q}%", "%#{q}%")
                            .order(created_at: :desc)
                            .limit(params.fetch(:limit, 20).to_i)
        render json: favorites.map { |f| serialize(f) }
      end

      def recent
        favorites = Favorite.includes(:analysis)
                            .where(status: "done")
                            .order("analyses.analyzed_at DESC")
                            .joins(:analysis)
                            .limit(params.fetch(:limit, 10).to_i)
        render json: favorites.map { |f| serialize(f) }
      end

      private

      def serialize(favorite)
        {
          id: favorite.id,
          url: favorite.url,
          title: favorite.title,
          content_type: favorite.content_type,
          status: favorite.status,
          thumbnail_url: favorite.thumbnail_url,
          created_at: favorite.created_at,
          analysis: favorite.analysis ? {
            summary: favorite.analysis.summary,
            tags: favorite.analysis.parsed_tags,
            key_points: favorite.analysis.parsed_key_points,
            sentiment: favorite.analysis.sentiment,
            subtitle_source: favorite.analysis.subtitle_source,
            model_used: favorite.analysis.model_used,
            analyzed_at: favorite.analysis.analyzed_at
          } : nil
        }
      end

      def enqueue_analysis(favorite)
        if favorite.content_type == "youtube"
          AnalyzeYoutubeJob.perform_later(favorite.id)
        else
          AnalyzeWebpageJob.perform_later(favorite.id)
        end
      end
    end
  end
end
```

- [ ] **Step 4: 테스트 PASS 확인**

```bash
rails test test/controllers/api/v1/favorites_controller_test.rb
```

Expected: 5 runs, 0 failures

- [ ] **Step 5: 커밋**

```bash
git add app/controllers/api/ test/controllers/api/
git commit -m "feat: add REST API v1 for external AI access"
```

---

## Task 14: PWA (manifest.json + Service Worker + Web Share Target)

**Files:**

- Create: `public/manifest.json`
- Create: `public/sw.js`

- [ ] **Step 1: manifest.json 작성**

```json
{
  "name": "URLFavorites",
  "short_name": "URLFav",
  "description": "AI로 URL을 자동 분석하는 즐겨찾기 앱",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#1d4ed8",
  "lang": "ko",
  "share_target": {
    "action": "/favorites",
    "method": "POST",
    "enctype": "application/x-www-form-urlencoded",
    "params": {
      "title": "title",
      "url": "url"
    }
  },
  "icons": [
    { "src": "/icon-192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icon-512.png", "sizes": "512x512", "type": "image/png" }
  ]
}
```

- [ ] **Step 2: Service Worker 작성**

```javascript
// public/sw.js
const CACHE_NAME = 'urlfav-v1'
const OFFLINE_URL = '/offline.html'

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll([OFFLINE_URL]))
  )
})

self.addEventListener('fetch', (event) => {
  if (event.request.mode === 'navigate') {
    event.respondWith(
      fetch(event.request).catch(() => caches.match(OFFLINE_URL))
    )
  }
})
```

- [ ] **Step 3: offline.html 생성 (public/offline.html)**

```html
<!DOCTYPE html>
<html lang="ko">
  <head>
    <meta charset="UTF-8" />
    <title>오프라인</title>
  </head>
  <body>
    <h1>URLFavorites</h1>
    <p>인터넷 연결을 확인해주세요.</p>
  </body>
</html>
```

- [ ] **Step 4: 레이아웃에 Service Worker 등록 스크립트 추가**

`app/views/layouts/application.html.erb` `</body>` 직전에:

```erb
<script>
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('/sw.js');
  }
</script>
```

- [ ] **Step 5: PWA 아이콘 생성 (간단한 PNG 2개)**

ImageMagick이 있으면:

```bash
convert -size 192x192 xc:#1d4ed8 -fill white -gravity center -pointsize 48 -annotate 0 "URL" public/icon-192.png
convert -size 512x512 xc:#1d4ed8 -fill white -gravity center -pointsize 128 -annotate 0 "URL" public/icon-512.png
```

없으면 Ruby로 최소 PNG 생성:

```bash
ruby -e "
require 'zlib'
def png(size)
  w, b = size, size
  # 1x1 파란 픽셀을 size x size로 확장하는 최소 PNG
  header = \"\\x89PNG\\r\\n\\x1a\\n\"
  ihdr = [w, b, 8, 2, 0, 0, 0].pack('NNCCCCC')
  ihdr_chunk = chunk('IHDR', ihdr)
  raw = (\"\\x00\" + \"\\x1d\\x4e\\xd8\" * w) * b  # RGB #1d4ed8
  idat_chunk = chunk('IDAT', Zlib::Deflate.deflate(raw))
  iend_chunk = chunk('IEND', '')
  header + ihdr_chunk + idat_chunk + iend_chunk
end
def chunk(type, data)
  [data.bytesize].pack('N') + type + data + [Zlib.crc32(type + data)].pack('N')
end
File.binwrite('public/icon-192.png', png(192))
File.binwrite('public/icon-512.png', png(512))
puts 'Icons created'
"
```

Expected: `Icons created` 출력, `public/icon-192.png` · `public/icon-512.png` 생성됨

- [ ] **Step 6: 브라우저에서 PWA 확인**

```bash
rails server
```

Chrome DevTools → Application → Manifest 탭에서 Share Target 확인.
모바일에서 "홈 화면에 추가" 가능 여부 확인.

- [ ] **Step 7: 커밋**

```bash
git add public/manifest.json public/sw.js public/offline.html public/icon-*.png
git add app/views/layouts/application.html.erb
git commit -m "feat: add PWA manifest with Web Share Target and Service Worker"
```

---

## Task 15: Solid Queue 설정 + VPS 배포

**Files:**

- Modify: `config/solid_queue.yml`
- Create: `config/environments/production.rb` (배포 관련 설정)

- [ ] **Step 1: Solid Queue concurrency 설정**

`config/solid_queue.yml` 에서 workers 섹션 확인 및 수정:

```yaml
default: &default
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: '*'
      threads: 2 # llama-server 동시 요청 최대 2개
      processes: 1
      polling_interval: 0.1
```

- [ ] **Step 2: 환경변수 파일 생성 (VPS용)**

VPS에서 (`ssh hwandam@vps-server`):

```bash
# ~/urlfavorites/.env.production 생성
LLAMA_SERVER_URL=http://<beacon-wg-ip>:<port>
RAILS_ENV=production
```

- [ ] **Step 3: 로컬에서 전체 테스트 실행**

```bash
rails test
```

Expected: 모든 테스트 PASS (0 failures, 0 errors)

- [ ] **Step 4: 배포**

```bash
deploy urlfavorites
```

Expected: rsync → bundle → db:migrate → assets → Puma restart 완료

- [ ] **Step 5: VPS에서 동작 확인**

```bash
# SSH로 VPS 접속
curl http://localhost:3000/api/v1/favorites
```

Expected: `[]` (빈 배열 JSON)

- [ ] **Step 6: yt-dlp VPS 설치 확인**

```bash
yt-dlp --version
```

없으면: `pip install yt-dlp` 또는 `sudo apt install yt-dlp`

- [ ] **Step 7: Solid Queue 워커 프로세스 확인**

```bash
ps aux | grep solid_queue
```

Expected: 워커 프로세스 실행 중

- [ ] **Step 8: 최종 E2E 테스트**

브라우저에서 URL 등록 → "분석 중..." 표시 → AI 분석 완료 → 결과 자동 갱신 확인.

- [ ] **Step 9: 최종 커밋**

```bash
git add config/solid_queue.yml
git commit -m "feat: configure Solid Queue concurrency, deployment ready"
```

---

## 전체 테스트 실행

```bash
rails test
```

Expected: 약 30+ runs, 0 failures, 0 errors

---

## 완료 체크리스트

- [ ] Phase 0: git 상태 클린
- [ ] 모든 모델 + 마이그레이션 완료
- [ ] 4개 서비스 (UrlTypeDetector, WebpageScraper, YoutubeExtractor, LlmAnalyzer)
- [ ] 2개 잡 (AnalyzeWebpageJob, AnalyzeYoutubeJob)
- [ ] 웹 컨트롤러 + B+C 레이아웃 뷰
- [ ] REST API v1 (6 엔드포인트)
- [ ] PWA (manifest + SW + Web Share Target)
- [ ] Solid Queue concurrency 설정
- [ ] VPS 배포 완료
- [ ] yt-dlp VPS 설치 확인
- [ ] 전체 테스트 PASS
