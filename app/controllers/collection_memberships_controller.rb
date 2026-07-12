class CollectionMembershipsController < ApplicationController
  def create
    collection_id = params.dig(:collection_membership, :collection_id)
    @favorite = UrlFavorites::UseCases::Collections::AddFavoriteToCollection.call(
      favorite_id: params[:favorite_id],
      collection_id: collection_id
    )
    redirect_to favorite_url(@favorite)
  end

  def destroy
    collection_id = params.dig(:collection_membership, :collection_id)
    @favorite = UrlFavorites::UseCases::Collections::RemoveFavoriteFromCollection.call(
      favorite_id: params[:favorite_id],
      collection_id: collection_id
    )
    redirect_to favorite_url(@favorite)
  end
end
