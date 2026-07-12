class CollectionsController < ApplicationController
  def index
    @collections = Collection.all.order(created_at: :desc)
  end

  def show
    @collection = Collection.find(params[:id])
    @favorites = @collection.favorites.includes(:analysis)
  end

  def create
    @collection = Collection.new(collection_params)
    if @collection.save
      redirect_to collection_url(@collection), notice: "Collection created"
    else
      @collections = Collection.all.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @collection = Collection.find(params[:id])
    if @collection.update(collection_params)
      redirect_to collection_url(@collection), notice: "Collection updated"
    else
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    @collection = Collection.find(params[:id])
    @collection.destroy
    redirect_to collections_url, notice: "Collection deleted"
  end

  private

  def collection_params
    params.require(:collection).permit(:name, :description)
  end
end
