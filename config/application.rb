require_relative "boot"

require "rails/all"

# Gemfile 에 나열된 gems 을 포함하여 필요한 gems 을 로드합니다.
# :test, :development, 또는 :production 으로 제한한 gems 도 포함됩니다.
Bundler.require(*Rails.groups)

module UrlFavorites20
  class Application < Rails::Application
    # 원래 생성된 Rails 버전의 기본 설정을 초기화합니다.
    config.load_defaults 8.1

    # .rb 파일이 없거나 재로딩하거나 eager load 하지 않으려는 다른 `lib` 하위 디렉토리를 `ignore` 목록에 추가하세요.
    # .rb 파일을 포함하지 않거나 재로딩하거나 eager load 하지 않으려는 하위 디렉토리도 포함됩니다.
    # 예를 들어 `templates`, `generators`, 또는 `middleware` 등이 있습니다.
    config.autoload_lib(ignore: %w[assets tasks])

    # FTS5 가상 테이블은 schema.rb 에 덤프할 수 없으므로 SQL format 을 사용합니다.
    config.active_record.schema_format = :sql

    # 애플리케이션, 엔진, 및 railties 설정은 여기에 들어갑니다.
    #
    # 이러한 설정은 특정 환경에서 config/environments 파일들을 사용하여 오버라이드할 수 있습니다.
    # config/environments 파일들은 나중에 처리됩니다.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
