# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

# 서브패스 배포 지원: RAILS_RELATIVE_URL_ROOT=/ver2.0 설정 시
# Rack 레벨에서 prefix를 스트립하여 Rails 라우터에 올바른 PATH_INFO 전달
if (prefix = ENV["RAILS_RELATIVE_URL_ROOT"].presence)
  map prefix do
    run Rails.application
  end
else
  run Rails.application
end
Rails.application.load_server
