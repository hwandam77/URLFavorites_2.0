module UrlFavorites
  module UseCases
    module Search
      class FavoriteSearch
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
          return filtered_favorites if @query.blank?

          terms = fts_terms
          return [] if terms.empty?

          results = fts_search(terms)
          return results if results.present?

          semantic_search
        end

        private

        def apply_sort(scope)
          case @sort
          when "oldest"
            scope.order(created_at: :asc)
          when "title"
            scope.order("COALESCE(title, url) ASC")
          else
            scope.order(created_at: :desc)
          end
        end

        def fts_terms
          @query.split(/[^\p{Word}]+/).reject(&:blank?)
        end

        def fts_search(terms)
          match_expr = terms.map { |term| "#{term}*" }.join(" ")

          sql = "SELECT favorite_id FROM favorites_fts WHERE favorites_fts MATCH ?"
          rows = ActiveRecord::Base.connection.execute(
            ActiveRecord::Base.send(:sanitize_sql_array, [ sql, match_expr ])
          )
          ids = rows.map { |r| r["favorite_id"] }.compact
          return [] if ids.empty?

          scope = Favorite.includes(:analysis).where(id: ids)
          scope = apply_filters(scope)
          apply_sort(scope)
        end

        def filtered_favorites
          scope = Favorite.includes(:analysis).all
          scope = apply_filters(scope)
          apply_sort(scope)
        end

        def apply_filters(scope)
          scope = scope.where(content_type: @content_type) if @content_type.present?
          scope = scope.where(status: @status) if @status.present?
          scope = scope.joins(:collection_memberships).where(collection_memberships: { collection_id: @collection_id }) if @collection_id.present?
          scope = scope.where(pinned: true) if @category == "핀"
          scope = scope.where(category: @category) if @category.present? && @category != "전체" && @category != "핀"
          scope
        end

        def semantic_search
          results = UrlFavorites::Integrations::Search::SemanticClient.call(
            query: @query,
            content_type: @content_type,
            status: @status,
            collection_id: @collection_id,
            sort: @sort
          )
          apply_array_filters(results)
        end

        # SemanticClient 는 category·pinned 를 모른다. 배열에 사후 적용한다
        def apply_array_filters(results)
          return results if @category.blank? || @category == "전체"
          return results.select(&:pinned) if @category == "핀"
          results.select { |f| f.category == @category }
        end
      end
    end
  end
end
