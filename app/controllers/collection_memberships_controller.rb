class CollectionMembershipsController < ApplicationController
  def create
    @favorite = Favorite.find(params[:favorite_id])
    collection_id = params.dig(:collection_membership, :collection_id)
    unless CollectionMembership.exists?(favorite: @favorite, collection_id: collection_id)
      CollectionMembership.create!(favorite: @favorite, collection_id: collection_id)
    end
    redirect_to favorite_url(@favorite)
  end

  def destroy
    @favorite = Favorite.find(params[:favorite_id])
    collection_id = params.dig(:collection_membership, :collection_id)
    membership = CollectionMembership.find_by(favorite: @favorite, collection_id: collection_id)
    membership&.destroy
    redirect_to favorite_url(@favorite)
  end
end
