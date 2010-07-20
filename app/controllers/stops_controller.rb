class StopsController < LocationsController
  
  def show
    @stop = Stop.full_find(params[:id], params[:scope])
    @new_campaign = Campaign.new(:reporter => User.new)
    @title = @stop.full_name
    if location_search
      location_search.add_location(@stop) 
      if @stop.transport_mode_ids.include? location_search.transport_mode_id
        @new_campaign.transport_mode_id = location_search.transport_mode_id 
      end
    end
    respond_to do |format|
      format.html
      format.atom do  
        @campaigns = @stop.campaigns.confirmed
        render :template => 'shared/campaigns.atom.builder', :layout => false 
      end
    end
  end
  
  def update
    @stop = Stop.full_find(params[:id], params[:scope])
    update_location(@stop, params[:stop])
  end
  
  private
  
  def model_class
    Stop
  end
  
end