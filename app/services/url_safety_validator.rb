require "uri"
require "ipaddr"

class UrlSafetyValidator
  BLOCKED_HOSTS = %w[localhost].freeze

  def self.call(url)
    return false unless url.is_a?(String) && url.match?(/\Ahttps?:\/\//i)

    uri = URI.parse(url)

    # 호스트 확인
    host = uri.host&.gsub(/\[|\]/, "")
    return false if host.nil? || host.empty?
    return false if BLOCKED_HOSTS.include?(host.downcase)

    # IP 주소 확인
    begin
      ip = IPAddr.new(host)
      return false if ip.private? || ip.loopback?
    rescue IPAddr::InvalidAddressError
      # IP 주식이 아님 — 호스트네임이 허용됨
    end

    true
  rescue URI::InvalidURIError
    false
  end
end
