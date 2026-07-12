class FavoriteNotesController < ApplicationController
  def update
    @favorite = UrlFavorites::UseCases::Notes::UpdateFavoriteNote.call(
      favorite_id: params[:favorite_id],
      note: params.dig(:favorite, :note)
    )
    redirect_to favorite_url(@favorite), notice: "Note updated"
  end
end
