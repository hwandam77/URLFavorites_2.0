class CollectionsController < ApplicationController
  def index
    @collections = Collection.all.order(created_at: :desc)
  end

  def show
    @collection = Collection.find(params[:id])
    @favorites = @collection.favorites.includes(:analysis)
  end

  def create
    result = UrlFavorites::UseCases::Collections::CreateCollection.call(
      name: collection_params[:name],
      description: collection_params[:description]
    )
    if result.ok?
      redirect_to collection_url(result.value[:collection]), notice: "Collection created"
    else
      @collections = Collection.all.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def update
    result = UrlFavorites::UseCases::Collections::UpdateCollection.call(
      id: params[:id],
      name: collection_params[:name],
      description: collection_params[:description]
    )
    if result.ok?
      redirect_to collection_url(result.value[:collection]), notice: "Collection updated"
    else
      @collection = Collection.find(params[:id])
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    UrlFavorites::UseCases::Collections::DeleteCollection.call(id: params[:id])
    redirect_to collections_url, notice: "Collection deleted"
  end

  private

  def collection_params
    params.require(:collection).permit(:name, :description)
  end
end
