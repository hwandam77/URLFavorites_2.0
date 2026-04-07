require "open3"
require "json"
require "shellwords"

class YoutubeExtractor
  class ExtractionError < StandardError; end

  def self.call(url)
    command = "yt-dlp --dump-json #{Shellwords.escape(url)}"
    stdout, _stderr, status = Open3.capture3(command)

    raise ExtractionError, "yt-dlp failed" unless status.success?
    raise ExtractionError, "yt-dlp output is empty" if stdout.strip.empty?

    data = JSON.parse(stdout)

    title       = data["title"].to_s
    description = data["description"].to_s
    transcript  = extract_transcript(data)
    transcript  = transcript[0...12_000]

    { title: title, description: description, transcript: transcript }
  rescue JSON::ParserError => e
    raise ExtractionError, "JSON parse failed: #{e.message}"
  end

  def self.extract_transcript(data)
    subtitles   = data["subtitles"] || {}
    auto_caps   = data["automatic_captions"] || {}

    # 1순위: subtitles
    result = captions_text(subtitles, "en") ||
             captions_text(subtitles, subtitles.keys.first)

    # 2순위: automatic_captions
    result ||= captions_text(auto_caps, "en") ||
               captions_text(auto_caps, auto_caps.keys.first)

    # 3순위: description
    result || data["description"].to_s
  end

  def self.captions_text(captions_hash, lang_key)
    return nil unless lang_key && captions_hash.key?(lang_key)

    items = captions_hash[lang_key]
    return nil unless items.is_a?(Array) && !items.empty?

    items.map { |item| item["text"].to_s }.join(" ").strip.presence
  end
end
