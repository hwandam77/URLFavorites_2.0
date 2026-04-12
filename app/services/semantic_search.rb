# frozen_string_literal: true

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

    # Get candidates with embeddings (limited batch)
    candidates = fetch_candidates_with_embeddings

    # Calculate cosine similarity
    scored = candidates.map do |candidate|
      embedding = parse_embedding(candidate[:content_embedding])
      next unless embedding.present?

      similarity = cosine_similarity(query_embedding, embedding)
      candidate.merge(similarity: similarity)
    end.compact

    # Sort by similarity
    scored = scored.sort_by { |c| -c[:similarity] }

    return [] if scored.empty?

    # Batch fetch favorites and preserve similarity order
    favorite_ids = scored.map { |c| c[:favorite_id] }
    favorites_map = Favorite.where(id: favorite_ids).index_by(&:id)

    results = scored.map { |c| favorites_map[c[:favorite_id]] }.compact

    # Apply filters (content_type, status, collection_id)
    results = filter_by_content_type(results)
    results = filter_by_status(results)
    results = filter_by_collection_id(results)

    results.first(@limit)
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
    sql = "SELECT favorite_id, content_embedding FROM favorites_fts WHERE content_embedding IS NOT NULL LIMIT 1000"
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
    return 0 if a.empty? || b.empty? || a.length != b.length
    dot_product = a.zip(b).map { |x, y| x * y }.sum
    magnitude_a = Math.sqrt(a.map { |x| x**2 }.sum)
    magnitude_b = Math.sqrt(b.map { |x| x**2 }.sum)
    return 0 if magnitude_a.zero? || magnitude_b.zero?
    dot_product / (magnitude_a * magnitude_b)
  end

  def filter_by_content_type(favorites)
    return favorites unless @content_type.present?
    favorites.select { |f| f.content_type == @content_type }
  end

  def filter_by_status(favorites)
    return favorites unless @status.present?
    favorites.select { |f| f.status == @status }
  end

  def filter_by_collection_id(favorites)
    return favorites unless @collection_id.present?
    favorites.select { |f| f.collection_memberships.any? { |m| m.collection_id == @collection_id } }
  end
end
