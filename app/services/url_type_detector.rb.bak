class UrlTypeDetector
  YOUTUBE_PATTERNS = [
    /\Ahttps?:\/\/(www\.)?youtube\.com\/(watch|shorts|embed|v|playlist)/i,
    /\Ahttps?:\/\/(www\.)?youtube\.com\/(@|channel|c)\//i,
    /\Ahttps?:\/\/youtu\.be\//i
  ].freeze

  def self.call(url)
    return "webpage" unless url.is_a?(String) && url.match?(/\Ahttps?:\/\//i)
    YOUTUBE_PATTERNS.any? { |pattern| url.match?(pattern) } ? "youtube" : "webpage"
  end
end
