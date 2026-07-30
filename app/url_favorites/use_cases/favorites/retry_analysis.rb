module UrlFavorites
  module UseCases
    module Favorites
      class RetryAnalysis
        def self.call(id:, analysis_style: UrlFavorites::Domain::Analysis::PromptStyle::DEFAULT)
          favorite = Favorite.find(id)
          # 수동 재분석은 캐시된 raw_content 를 버리고 새로 추출 (잘못 스크랩된 본문 재사용 방지)
          favorite.update!(status: "analyzing", error_message: nil, raw_content: nil)
          UrlFavorites::UseCases::Analysis::EnqueueAnalysis.call(
            favorite_id: favorite.id,
            analysis_style: analysis_style
          )
          favorite
        end
      end
    end
  end
end
