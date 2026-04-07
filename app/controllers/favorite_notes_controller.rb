class FavoriteNotesController < ApplicationController
  def update
    @favorite = Favorite.find(params[:favorite_id])
    @favorite.update!(note: params.dig(:favorite, :note))
    ReindexFavoriteJob.perform_later(@favorite.id)
    redirect_to favorite_url(@favorite), notice: "Note updated"
  end
end
