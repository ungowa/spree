class Admin::TaxonsController < Admin::BaseController
  resource_controller
  
  before_filter :load_object, :only => [:selected, :available, :remove]
  belongs_to :product
  
  create.wants.js {render :text => @taxon.to_json()}
  update.wants.js {render :text => @taxon.name}
  destroy.wants.js {render :text => ""}
  
  create.before do 
    @taxon.taxonomy_id = params[:taxonomy_id]
    @taxon.position = Taxon.find(@taxon.parent_id).children.length + 1
  end
  
  update.before do
   
    if params[:taxon].include? "parent_id"  #taxon being moved to new parent
      @previous_parent_id = @taxon.parent_id
      
      if params[:taxon].include? "position" #taxon being moved up or down aswell as new parent
       
        #get taxons that's been forced out of the way
        taxons = Taxon.find_all_by_parent_id(params[:taxon][:parent_id])
        taxons = taxons.reject{ |t| t.id == @taxon.id}
          
        taxons.each do |taxon|
          if taxon.position >= params[:taxon][:position].to_f
            taxon.position += 1
          end
          taxon.save!
        end
      end
      
    elsif params[:taxon].include? "position" #taxon being moved up or down (same parent)
      #get all taxons under same parent
      taxons = Taxon.find_all_by_parent_id(@taxon.parent_id)
      total_taxons = taxons.length
      taxons = taxons.reject{ |t| t.id == @taxon.id}
      
      if params[:taxon][:position].to_f == total_taxons #being moved/dropped at the end of the children list, everything moves up one (-1)
        taxons.each do |taxon|
          if taxon.position >= @taxon.position #only affects node higher that node being moved
            taxon.position += -1
            taxon.save!
          end
        end
      elsif params[:taxon][:position].to_f == 1 #being moved/dropped at the start of the children list, everything moves up down (1)
        taxons.each do |taxon|
          if taxon.position <= @taxon.position #only affects node lower that node being moved
            taxon.position += 1
            taxon.save!
          end
        end
      else  #being moved/dropped BEFORE the end of the list.
        logger.debug("#{@taxon.position} > #{params[:taxon][:position].to_f}")
        logger.debug("#{@taxon.position} < #{params[:taxon][:position].to_f}")
        
        if @taxon.position > params[:taxon][:position].to_f #old position greater than new postion
          logger.debug("=======UP======")
          #up
          taxons.each do |taxon|
            logger.debug("#{taxon.position} <= #{@taxon.position} && #{taxon.position} >= #{params[:taxon][:position].to_f}")
            if taxon.position <= @taxon.position && taxon.position >= params[:taxon][:position].to_f
              taxon.position += 1
              taxon.save!
            end
          end
        elsif @taxon.position < params[:taxon][:position].to_f #old position less than new position
           logger.debug("=======DOWN======")
          #down
          taxons.each do |taxon|
            logger.debug  ("#{taxon.position} >= #{@taxon.position} && #{taxon.position} <= #{params[:taxon][:position].to_f}")
            if taxon.position >= @taxon.position && taxon.position <= params[:taxon][:position].to_f
              taxon.position += -1
              taxon.save!              
            end
          end
        end
        
      end
    
        
    end 
  end
  
  update.after do
    #reposition old parent's children after move to new parent
    reposition_taxons(Taxon.find_all_by_parent_id(@previous_parent_id, :order => "position ASC")) if @previous_parent_id
  end
  
  destroy.after do
    reposition_taxons(Taxon.find_all_by_taxonomy_id(@taxon.taxonomy_id, :order => "position ASC"))

  end
    
  def selected 
    @taxons = @product.taxons
  end
  
  def available
    if params[:q].blank?
      @available_taxons = []
    else
      @available_taxons = Taxon.find(:all, :conditions => ['lower(name) LIKE ?', "%#{params[:q].downcase}%"])
    end
    @available_taxons.delete_if { |taxon| @product.taxons.include?(taxon) }
    respond_to do |format|
      format.html
      format.js {render :layout => false}
    end

  end
  
  def remove
    @product.taxons.delete(@taxon)
    @product.save
    @taxons = @product.taxons
    render :layout => false
  end  
  
  def select
    @product = Product.find_by_param!(params[:product_id])
    taxon = Taxon.find(params[:id])
    @product.taxons << taxon
    @product.save
    @taxons = @product.taxons
    render :layout => false
  end
  
  private 
  def reposition_taxons(taxons)
    taxons.each_with_index do |taxon, i|
        taxon.position = (i + 1)
        taxon.save!
    end
  end
end