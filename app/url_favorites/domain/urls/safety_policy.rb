require "uri"
require "ipaddr"
require "socket"

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

          ip_blocked = blocked_ip?(host)
          resolves_to_blocked_ip = resolves_to_private?(host)
          return false if ip_blocked || resolves_to_blocked_ip

          true
        rescue URI::InvalidURIError
          false
        end

        def self.blocked_ip?(host)
          ip = IPAddr.new(host)
          blocked_ip_address?(ip)
        rescue IPAddr::InvalidAddressError
          false
        end

        def self.resolves_to_private?(host)
          Addrinfo.getaddrinfo(host, nil, nil, :STREAM).any? do |addr|
            blocked_ip_address?(IPAddr.new(addr.ip_address))
          end
        rescue IPAddr::InvalidAddressError, SocketError
          host.match?(/\A[\d.]+\z/)
        end

        def self.blocked_ip_address?(ip)
          ip.loopback? || ip.private? || ip.link_local? ||
            BLOCKED_IP_RANGES.any? { |range| IPAddr.new(range).include?(ip) }
        end
      end
    end
  end
end
