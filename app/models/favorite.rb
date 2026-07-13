class Favorite < ApplicationRecord
  CONTENT_TYPES = %w[webpage youtube github twitter].freeze
  CATEGORIES = %w[전체 핀 AI에이전트 AI코딩 튜토리얼 AI모델 개발도구 뉴스/커뮤니티 기타].freeze
  SELECTABLE_CATEGORIES = CATEGORIES - %w[전체 핀]
  STATUSES = %w[pending analyzing done failed].freeze

  has_one :analysis, dependent: :destroy
  has_many :collection_memberships, dependent: :destroy
  has_many :collections, through: :collection_memberships

  validates :url, presence: true, uniqueness: true
  validates :content_type, inclusion: { in: CONTENT_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :category, inclusion: { in: CATEGORIES }

  # Turbo Stream: 분석 완료/실패 시 자동으로 카드 갱신
  after_update_commit -> {
    broadcast_replace_to :favorites
    broadcast_refresh_to self
  }

  # Instance predicates for statuses
  STATUSES.each do |s|
    define_method(:"#{s}?") { status == s }
  end

  # Scope for pinned favorites
  scope :pinned, -> { where(pinned: true) }
  scope :recent_done, -> { where(status: "done").order(updated_at: :desc) }

  # Detect content type from URL
  def detect_content_type
    return content_type if content_type.present?

    if url.to_s.match?(/\Ahttps?:\/\/(www\.)?(youtube\.com|youtu\.be)/i)
      "youtube"
    elsif url.to_s.match?(/\Ahttps?:\/\/(www\.)?github\.com/i)
      "github"
    else
      "webpage"
    end
  end
end
