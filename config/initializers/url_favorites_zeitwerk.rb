# frozen_string_literal: true

# Rails가 `app/url_favorites` 디렉토리를 autoload path root 로 취급하면
# `UrlFavorites::...` 네임스페이스가 아닌 `UseCases::...` 같은 top-level 상수를 기대한다.
# 따라서 해당 디렉토리를 `UrlFavorites` 네임스페이스로 매핑한다.

require Rails.root.join("app/url_favorites").to_s

Rails.autoloaders.main.push_dir(Rails.root.join("app/url_favorites"), namespace: UrlFavorites)
