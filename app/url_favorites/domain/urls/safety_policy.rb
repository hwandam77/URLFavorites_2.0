require "uri"
require "ipaddr"

module UrlFavorites
  module Domain
    module Urls
      class SafetyPolicy
        BLOCKED_HOSTS = %w[localhost].freeze
        BLOCKED_IP_RANGES = %w[127.0.0.0/8 0.0.0.0/8 169.254.0.0/16 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 ::1/128 fc00::/7 fe80::/10].freeze
        BLOCKED_SUFFIXES = %w[.local .internal .corp].freeze

        def self.allowed?(url)
          return false unless url.is_a?(String) && url.match?(/\Ahttps?:\/\//i)

          uri = URI.parse(url)

          host = uri.host&.gsub(/\[|\]/, "")
          return false if host.nil? || host.empty?
          return false if BLOCKED_HOSTS.include?(host.downcase)
          return false if BLOCKED_SUFFIXES.any? { |s| host.downcase.end_with?(s) }

          return false if blocked_ip?(host)
          return false if resolves_to_private?(host)

          true
        rescue URI::InvalidURIError
          false
        end

        def self.blocked_ip?(host)
          ip = IPAddr.new(host)
          ip.loopback? || ip.private? || ip.link_local? ||
            BLOCKED_IP_RANGES.any? { |range| IPAddr.new(range).include?(ip) }
        rescue IPAddr::InvalidAddressError
          false
        end

        def self.resolves_to_private?(host)
          return false if host.match?(/\A\d+\.\d+\.\d+\.\d+\z/)

          addr = Addrinfo.getaddrinfo(host, nil, nil, :STREAM).first
          return false unless addr

          ip = IPAddr.new(addr.ip_address)
          ip.loopback? || ip.private? || ip.link_local?
        rescue IPAddr::InvalidAddressError, SocketError
          false
        end
      end
    end
  end
end
