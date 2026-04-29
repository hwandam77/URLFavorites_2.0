module ApplicationHelper
  def github_repo_name(url)
    return url unless url.to_s.include?("github.com")

    # Extract owner/repo from github.com URLs
    # https://github.com/owner/repo -> owner/repo
    # https://github.com/owner/repo/issues/123 -> owner/repo
    match = url.to_s.match(%r{github\.com/([^/]+/[^/]+)})
    match ? match[1] : url
  end

  def youtube_timestamp_url(url, timestamp)
    video_id = youtube_video_id(url)
    seconds = timestamp_to_seconds(timestamp)
    return nil if video_id.blank? || seconds.nil?

    "https://www.youtube.com/watch?v=#{video_id}&t=#{seconds}s"
  end

  def youtube_video_id(url)
    uri = URI.parse(url.to_s)
    return uri.path.delete_prefix("/") if uri.host.to_s.include?("youtu.be")

    params = Rack::Utils.parse_query(uri.query)
    params["v"].presence
  rescue URI::InvalidURIError
    nil
  end

  def timestamp_to_seconds(timestamp)
    parts = timestamp.to_s.split(":").map(&:to_i)
    return nil unless [ 2, 3 ].include?(parts.length)

    if parts.length == 3
      hours, minutes, seconds = parts
      (hours * 3600) + (minutes * 60) + seconds
    else
      minutes, seconds = parts
      (minutes * 60) + seconds
    end
  end
end
