require "active_support/core_ext/integer/time"

Rails.application.configure do
  # 여기에서 설정한 값은 config/application.rb 의 설정보다 우선시됩니다.

  # 요청 간에 코드가 다시 로드되지 않습니다.
  config.enable_reloading = false

  # 부팅 시 코드를 미리 로드하여 성능 향상 및 메모리 절약 (Rake 작업에서 무시됨).
  config.eager_load = true

  # 전체 오류 보고는 비활성화됩니다.
  config.consider_all_requests_local = false

  # 뷰 템플릿에서 프래그먼트 캐싱을 켭니다.
  config.action_controller.perform_caching = true

  # 모든 디제스트 스탬프를 사용하므로 먼 미래까지 캐시됩니다.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # 이미지, 스타일시트, 자바스크립트를 자산 서버에서 제공하는 것을 활성화합니다.
  # config.asset_host = "http://assets.example.com"

  # 업로드된 파일을 로컬 파일 시스템에 저장합니다 (옵션은 config/storage.yml 참조).
  config.active_storage.service = :local

  # 앱에 대한 모든 접근이 SSL-종료 역 프록시를 통해 발생한다고 가정합니다.
  # config.assume_ssl = true

  # 앱에 대한 모든 접근을 SSL로 강제하고, Strict-Transport-Security 를 사용하며, 안전한 쿠키를 사용합니다.
  # config.force_ssl = true

  # 기본 건강 상태 확인 엔드포인트에 대한 http-to-https 리디렉션은 건너뜁니다.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # 현재 요청 id 를 기본 로그 태그로 사용하여 STDOUT 에 로그를 기록합니다.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # 모든 것을 기록합니다 (잠재적으로 개인 식별 정보를 포함할 수 있음!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # 건강 상태 확인이 로그를 막는 것을 방지합니다.
  config.silence_healthcheck_path = "/up"

  # 어떤 비호환성도 기록하지 않습니다.
  config.active_support.report_deprecations = false

  # 기본 인-프로세스 메모리 캐시 저장소를 영구적인 대안으로 교체합니다.
  # config.cache_store = :mem_cache_store

  # Active Job 의 기본 인-프로세스 및 비영구 큐잉 백엔드를 교체합니다.
  # config.active_job.queue_adapter = :resque

  # 잘못된 이메일 주소를 무시하고 이메일 전달 오류를 발생시키지 않습니다.
  # 즉시 전달을 위해 이메일 서버를 구성하고 전달 오류를 발생시키려면 이 값을 true 로 설정합니다.
  # config.action_mailer.raise_delivery_errors = false

  # 메일러 템플릿에서 생성된 링크에 사용될 호스트를 지정합니다.
  config.action_mailer.default_url_options = { host: "example.com" }

  # 아웃바운드 SMTP 서버를 지정합니다. bin/rails credentials:edit 를 통해 smtp/* 자격 증명을 추가하세요.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # I18n 로케일 폴백을 활성화합니다 (번역이 찾을 수 없을 때 모든 로케일 조회가 I18n.default_locale 으로 폴백됩니다).
  config.i18n.fallbacks = true

  # 마이그레이션 후 스키마를 덤프하지 않습니다.
  config.active_record.dump_schema_after_migration = false

  # 프로덕션에서는 :id 만 검사에 사용합니다.
  config.active_record.attributes_for_inspect = [ :id ]

  # DNS 리바인딩 보호 및 기타 `Host` 헤더 공격을 활성화합니다.
  # config.hosts = [
  #   "example.com",     # example.com 에서 오는 요청 허용
  #   /.*\.example\.com/ # www.example.com 과 같은 서브도메인 요청 허용
  # ]
  #
  # 기본 건강 상태 확인 엔드포인트에 대해 DNS 리바인딩 보호를 건너뜁니다.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

  # 서브패스 배포 (/ver2.0)
  config.relative_url_root = ENV.fetch("RAILS_RELATIVE_URL_ROOT", nil)

  # LLAMA_SERVER_URL 이 없으면 시작 거부 (AI 분석 필수 의존성)
  config.after_initialize do
    if ENV["LLAMA_SERVER_URL"].blank?
      raise "LLAMA_SERVER_URL environment variable is required"
    end
  end
end
