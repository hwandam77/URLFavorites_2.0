# app/services/favorite_search.rb
class FavoriteSearch
  # favorites_fts 가상 테이블에 대한 FTS5 전체 텍스트 검색
  # favorites_fts 열: favorite_id, title, summary, tags, note

  def self.call(query: nil, content_type: nil, status: nil, collection_id: nil, sort: "recent", category: nil)
    new(query: query, content_type: content_type, status: status, collection_id: collection_id, sort: sort, category: category).call
  end

  def initialize(query:, content_type: nil, status: nil, collection_id: nil, sort: "recent", category: nil)
    @query = query&.strip
    @content_type = content_type
    @status = status
    @collection_id = collection_id
    @sort = sort
    @category = category
  end

  def call
    if @query.present?
      fts_search
    else
      filtered_favorites
    end
  end

  private

  def apply_sort(scope)
    case @sort
    when "oldest"
      scope.order(created_at: :asc)
    when "title"
      scope.order("COALESCE(title, url) ASC")
    else # "recent" or default
      scope.order(created_at: :desc)
    end
  end

  def fts_search
    sanitized = @query.gsub(/[^a-zA-Z0-9 ]/, "").strip
    return [] if sanitized.blank?

    sql = "SELECT favorite_id FROM favorites_fts WHERE favorites_fts MATCH ?"
    rows = ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.send(:sanitize_sql_array, [ sql, sanitized + "*" ])
    )
    ids = rows.map { |r| r["favorite_id"] }.compact
    return [] if ids.empty?

    scope = Favorite.where(id: ids)
    scope = apply_filters(scope)
    apply_sort(scope)
  end

  def filtered_favorites
    scope = Favorite.all
    scope = apply_filters(scope)
    apply_sort(scope)
  end

  def apply_filters(scope)
    scope = scope.where(content_type: @content_type) if @content_type.present?
    scope = scope.where(status: @status) if @status.present?
    scope = scope.where(category: @category) if @category.present? && @category != "전체"
    scope = scope.where(pinned: true) if @category == "핀"
    scope
  end
end
