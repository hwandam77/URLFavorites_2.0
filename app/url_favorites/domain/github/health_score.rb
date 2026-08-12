require "json"

module UrlFavorites
  module Domain
    module Github
      # GitHub 리포지토리 건강도 스코어 (100점 만점).
      # RepoClient.build_metadata 가 반환한 해시를 받아 계산한다.
      #
      # 배점: 활동성 30 / 인기 25 / 성숙도 15 / 커뮤니티 15 / 크기 15
      class HealthScore
        GRADES = { S: [90, 100], A: [75, 89], B: [60, 74], C: [40, 59], D: [0, 39] }.freeze

        # { score:, grade:, breakdown:, label: }
        Result = Struct.new(:score, :grade, :breakdown, :label, keyword_init: true)

        def self.calculate(metadata)
          new(metadata).calculate
        end

        def initialize(metadata)
          @m = metadata || {}
        end

        def calculate
          activity  = score_activity
          popularity = score_popularity
          maturity  = score_maturity
          community = score_community
          size      = score_size

          total = [activity + popularity + maturity + community + size, 100].min
          grade = grade_for(total)

          Result.new(
            score: total,
            grade: grade,
            breakdown: {
              activity: activity,
              popularity: popularity,
              maturity: maturity,
              community: community,
              size: size
            },
            label: grade_label(grade)
          )
        end

        private

        attr_reader :m

        # ── 활동성 (30점) ──
        def score_activity
          return 0 if m["archived"]
          pushed = parse_time(m["pushed_at"])
          return 0 unless pushed
          diff = (Time.current - pushed).to_i
          return 30 if diff <= 7 * 86400
          return 20 if diff <= 30 * 86400
          return 10 if diff <= 90 * 86400
          0
        end

        # ── 인기 (25점, log-scale, 100스타 기준 16점) ──
        def score_popularity
          stars = (m["stars"] || 0).to_i
          return 0 if stars < 3
          (25 * Math.log10([stars, 3].max) / Math.log10(10_000)).round
        end

        # ── 성숙도 (15점, 프로젝트 연령) ──
        def score_maturity
          created = parse_time(m["created_at"])
          return 0 unless created
          age_days = (Time.current.to_i - created.to_i) / 86400.0
          return 15 if age_days >= 3 * 365.25
          return 13 if age_days >= 2 * 365.25
          return 10 if age_days >= 365.25
          0
        end

        # ── 커뮤니티 (15점, 포크/스타 비율 + 이슈 대비) ──
        def score_community
          stars = (m["stars"] || 0).to_i
          forks = (m["forks"] || 0).to_i
          return 0 if stars.zero?
          ratio = forks.to_f / stars
          return 15 if ratio >= 0.20
          return 12 if ratio >= 0.15
          return 10 if ratio >= 0.10
          return 7  if ratio >= 0.05
          3
        end

        # ── 크기 (15점, KB 단위) ──
        def score_size
          kb = (m["size"] || 0).to_i
          return 15 if kb >= 10_000
          return 10 if kb >= 1_000
          return 5  if kb >= 100
          0
        end

        def grade_for(score)
          GRADES.each { |g, (lo, _hi)| return g if score >= lo }
          :D
        end

        def grade_label(g)
          {
            S: "최고 — 활발하고 건강한 프로젝트",
            A: "매우 좋음 — 꾸준히 유지 중",
            B: "좋음 — 안정적",
            C: "보통 — 활동이 줄어듦",
            D: "주의 — 방치되었을 가능성"
          }[g]
        end

        def parse_time(iso_str)
          return nil unless iso_str
          Time.parse(iso_str)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
