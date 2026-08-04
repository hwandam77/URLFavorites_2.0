require "json"

module UrlFavorites
  module Integrations
    module Github
      class RepoClient
        API_BASE = "https://api.github.com"
        # owner/repo 만 뽑는다. /blob/... /tree/... /issues 같은 하위경로는 무시한다.
        REPO_PATTERN = %r{\Ahttps?://(?:www\.)?github\.com/([^/?#]+)/([^/?#]+)}i

        def self.call(url)
          match = url.to_s.match(REPO_PATTERN)
          return nil unless match

          owner = match[1]
          repo = match[2].sub(/\.git\z/i, "")
          meta, = fetch(owner, repo)
          meta
        end

        # github 타입 즐겨찾기 중 source_metadata 가 비어있는 것만 채운다 (재실행 가능).
        def self.backfill(limit: nil)
          scope = Favorite.where(content_type: "github").where(source_metadata: nil)
          scope = scope.limit(limit) if limit

          processed = 0
          skipped = 0
          stopped_by_rate_limit = false

          scope.find_each do |f|
            match = f.url.to_s.match(REPO_PATTERN)
            unless match
              skipped += 1
              Rails.logger.info("[RepoClient.backfill] skipped favorite=#{f.id}: not a repo URL (#{f.url})")
              next
            end

            meta, remaining = fetch(match[1], match[2].sub(/\.git\z/i, ""))

            # 한도 마지막 요청도 200 + remaining=0 으로 성공 결과를 주므로, meta 가 있으면 먼저 저장한다.
            if meta
              f.update!(source_metadata: meta)
              processed += 1
              Rails.logger.info("[RepoClient.backfill] processed favorite=#{f.id}")
            else
              skipped += 1
              Rails.logger.info("[RepoClient.backfill] skipped favorite=#{f.id}: fetch failed (#{f.url})")
            end

            if remaining == "0"
              stopped_by_rate_limit = true
              Rails.logger.warn("[RepoClient.backfill] rate limit exhausted, stopping")
              break
            end
          end

          { processed: processed, skipped: skipped, stopped_by_rate_limit: stopped_by_rate_limit }
        end

        # [meta_hash_or_nil, x-ratelimit-remaining 헤더값 또는 nil]
        def self.fetch(owner, repo)
          response = connection.get("/repos/#{owner}/#{repo}")
          remaining = response.headers["x-ratelimit-remaining"]
          Rails.logger.warn("[RepoClient] x-ratelimit-remaining is 0") if remaining == "0"

          unless response.status == 200
            Rails.logger.warn("[RepoClient] fetch failed owner=#{owner} repo=#{repo} status=#{response.status}")
            return [ nil, remaining ]
          end

          data = JSON.parse(response.body)
          [ build_metadata(data), remaining ]
        rescue Faraday::Error, JSON::ParserError => e
          Rails.logger.warn("[RepoClient] fetch failed owner=#{owner} repo=#{repo}: #{e.class}: #{e.message}")
          [ nil, nil ]
        end
        private_class_method :fetch

        def self.build_metadata(data)
          {
            "full_name" => data["full_name"],
            "description" => data["description"],
            "stars" => data["stargazers_count"],
            "forks" => data["forks_count"],
            "language" => data["language"],
            "topics" => Array(data["topics"]),
            "license" => data["license"]&.dig("spdx_id"),
            "pushed_at" => data["pushed_at"],
            "archived" => data["archived"],
            "fork" => data["fork"],
            "open_issues" => data["open_issues_count"],
            "fetched_at" => Time.current.iso8601
          }
        end
        private_class_method :build_metadata

        def self.connection
          @connection ||= Faraday.new(url: API_BASE) do |f|
            f.options.timeout = 10
            f.options.open_timeout = 10
          end.tap do |conn|
            conn.headers["Accept"] = "application/vnd.github+json"
            conn.headers["User-Agent"] = "URLFavorites"
            conn.headers["Authorization"] = "Bearer #{ENV['GITHUB_TOKEN']}" if ENV["GITHUB_TOKEN"].present?
          end
        end
        private_class_method :connection
      end
    end
  end
end
