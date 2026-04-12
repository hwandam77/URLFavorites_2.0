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
      suggestions.concat(diff[:added].to_a)
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
    all_corrections = TagFeedback.all.to_a

    {
      total_corrections: all_corrections.size,
      unique_favorites: all_corrections.map(&:favorite_id).uniq.size,
      popular_additions: tag_frequencies(all_corrections, :added),
      popular_removals: tag_frequencies(all_corrections, :removed)
    }
  end

  def find_similar_corrections(favorite)
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
      .flat_map { |c| c.tag_diff[diff_type].to_a }
      .compact
      .group_by(&:itself)
      .transform_values(&:count)
      .sort_by { |_, count| -count }
      .first(20)
      .to_h
  end
end
