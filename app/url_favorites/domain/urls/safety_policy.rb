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

          return false if blocked_ip?(host) || resolves_to_blocked?(host)

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

        def self.resolves_to_blocked?(host)
          Addrinfo.getaddrinfo(host, nil, nil, :STREAM).any? do |addr|
            blocked_ip_address?(IPAddr.new(addr.ip_address))
          end
        rescue IPAddr::InvalidAddressError, SocketError
          # shortcut: 16진·pct-인코딩 수치 표기의 차단은 glibc getaddrinfo 해석에 의존한다.
          #   libc을 musl 등으로 이식하면 이 우회를 재검증해야 한다.
          # 도메인 해석 실패는 허용 — fetch도 실패한다. 숫자·점 표기만 fail-closed.
          host.match?(/\A[\d.]+\z/)
        end

        def self.blocked_ip_address?(ip)
          ip = ip.native
          return true if ip.to_i.zero?

          ip.loopback? || ip.private? || ip.link_local? ||
            BLOCKED_IP_RANGES.any? { |range| IPAddr.new(range).include?(ip) }
        end
      end
    end
  end
end
