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
    {
      total_corrections: TagFeedback.count,
      unique_favorites: TagFeedback.select(:favorite_id).distinct.count,
      popular_additions: popular_tag_additions,
      popular_removals: popular_tag_removals
    }
  end

  def popular_tag_additions
    additions = Hash.new(0)
    TagFeedback.select(:id, :original_tags, :corrected_tags)
      .find_each do |tf|
        original_set = Set.new(Array(tf.original_tags))
        corrected_set = Set.new(Array(tf.corrected_tags))
        (corrected_set - original_set).each do |tag|
          additions[tag] += 1
        end
      end
    additions.sort_by { |_, count| -count }.first(20).to_h
  end

  def popular_tag_removals
    removals = Hash.new(0)
    TagFeedback.select(:id, :original_tags, :corrected_tags)
      .find_each do |tf|
        original_set = Set.new(Array(tf.original_tags))
        corrected_set = Set.new(Array(tf.corrected_tags))
        (original_set - corrected_set).each do |tag|
          removals[tag] += 1
        end
      end
    removals.sort_by { |_, count| -count }.first(20).to_h
  end

  def find_similar_corrections(favorite)
    begin
      uri = URI(favorite.url)
      domain = uri.host
    rescue URI::InvalidURIError => e
      Rails.logger.warn "[TagLearning] Invalid URL skipped: #{favorite.url} - #{e.message}"
      return []
    end
    return [] unless domain

    similar_favorites = Favorite.where(
      "url LIKE ?", "%#{domain}%"
    ).where.not(id: favorite.id)

    similar_favorite_ids = similar_favorites.pluck(:id)

    TagFeedback.where(favorite_id: similar_favorite_ids)
      .where("created_at > ?", 30.days.ago)
      .to_a
  end

end
