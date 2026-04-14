namespace :favorites do
  desc "URL 기반 카테고리 일괄 재분류"
  task recategorize: :environment do
    puts "카테고리 재분류 시작..."

    count = 0
    Favorite.find_each do |favorite|
      old_category = favorite.category
      new_category = UrlFavorites::Domain::Urls::CategoryDetector.call(favorite.url, favorite.content_type)

      if old_category != new_category
        favorite.update!(category: new_category)
        puts "  #{favorite.id}: #{favorite.url[0..60]}..."
        puts "    #{old_category} -> #{new_category}"
        count += 1
      end
    end

    puts "#{count}개 항목의 카테고리가 변경되었습니다."
  end

  desc "content_type 자동 재감지 (youtube/github)"
  task redetect_type: :environment do
    puts "content_type 재감지 시작..."

    count = 0
    Favorite.find_each do |favorite|
      detected = UrlFavorites::Domain::Urls::TypeDetector.call(favorite.url)
      if favorite.content_type != detected
        old = favorite.content_type
        favorite.update!(content_type: detected)
        puts "  #{favorite.id}: #{old} -> #{detected} (#{favorite.url[0..50]}...)"
        count += 1
      end
    end

    puts "#{count}개 항목의 content_type이 변경되었습니다."
  end
end
