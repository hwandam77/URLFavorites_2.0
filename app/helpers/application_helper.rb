module ApplicationHelper
  def github_repo_name(url)
    return url unless url.to_s.include?("github.com")

    # Extract owner/repo from github.com URLs
    # https://github.com/owner/repo -> owner/repo
    # https://github.com/owner/repo/issues/123 -> owner/repo
    match = url.to_s.match(%r{github\.com/([^/]+/[^/]+)})
    match ? match[1] : url
  end
end
