# frozen_string_literal: true

class Admin::CompanyDirectoryController < Admin::AdminController
  requires_plugin 'company-directory'
  
  before_action :ensure_staff
  before_action :find_listing, only: [:update_listing, :delete_listing]
  
  def index
    # Dashboard overview with statistics
    @stats = {
      total_listings: BusinessListing.count,
      active_listings: BusinessListing.active.count,
      inactive_listings: BusinessListing.inactive.count,
      featured_listings: BusinessListing.featured.count,
      pending_approval: BusinessListing.pending_approval.count,
      recent_signups: BusinessListing.where('created_at > ?', 7.days.ago).count
    }
    
    # Recent listings
    @recent_listings = BusinessListing.includes(:user)
                                     .order(created_at: :desc)
                                     .limit(10)
    
    respond_to do |format|
      format.html
      format.json { render json: { stats: @stats, recent_listings: serialize_listings(@recent_listings) } }
    end
  end
  
  def listings
    # Get filter parameters
    status_filter = params[:status]
    city_filter = params[:city]
    category_filter = params[:category]
    search_query = params[:search]
    page = [params[:page].to_i, 1].max
    per_page = 50
    
    # Build query
    listings = BusinessListing.includes(:user)
    
    case status_filter
    when 'active'
      listings = listings.active
    when 'inactive'
      listings = listings.inactive
    when 'featured'
      listings = listings.featured
    when 'pending'
      listings = listings.pending_approval
    end
    
    listings = listings.by_city(city_filter) if city_filter.present?
    listings = listings.by_category(category_filter) if category_filter.present?
    listings = listings.search(search_query) if search_query.present?
    
    # Order and paginate
    @listings = listings.order(created_at: :desc)
                       .offset((page - 1) * per_page)
                       .limit(per_page)
    
    @total_count = listings.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    
    # Filter options
    @cities = BusinessListing.distinct.pluck(:city).compact.sort
    @categories = BusinessListing.distinct.pluck(:category).compact.sort
    
    respond_to do |format|
      format.html { render :listings }
      format.json do
        render json: {
          listings: serialize_listings(@listings),
          pagination: {
            current_page: @current_page,
            total_pages: @total_pages,
            total_count: @total_count
          },
          filters: {
            cities: @cities,
            categories: @categories
          }
        }
      end
    end
  end
  
  def update_listing
    # Handle different update actions
    action = params[:action_type]
    
    case action
    when 'approve'
      @listing.update!(approved: true)
      message = "Listing approved successfully"
    when 'feature'
      @listing.update!(featured: true)
      message = "Listing featured successfully"
    when 'unfeature'
      @listing.update!(featured: false)
      message = "Listing unfeatured successfully"
    when 'activate'
      @listing.update!(is_active: true)
      message = "Listing activated successfully"
    when 'deactivate'
      @listing.update!(is_active: false)
      message = "Listing deactivated successfully"
    when 'update_priority'
      priority = params[:priority].to_i
      @listing.update!(priority: priority)
      message = "Listing priority updated successfully"
    else
      # Regular field updates
      if @listing.update(admin_listing_params)
        message = "Listing updated successfully"
      else
        return render json: { success: false, errors: @listing.errors.full_messages }, status: 422
      end
    end
    
    render json: {
      success: true,
      message: message,
      listing: serialize_listing(@listing)
    }
  end
  
  def delete_listing
    @listing.destroy!
    
    render json: {
      success: true,
      message: "Listing deleted successfully"
    }
  end
  
  def settings
    @settings = {
      company_directory_enabled: SiteSetting.company_directory_enabled,
      company_directory_subscription_plan_id: SiteSetting.company_directory_subscription_plan_id,
      company_directory_auto_approve: SiteSetting.company_directory_auto_approve,
      company_directory_max_images: SiteSetting.company_directory_max_images,
      company_directory_show_in_sitemap: SiteSetting.company_directory_show_in_sitemap,
      company_directory_featured_limit: SiteSetting.company_directory_featured_limit,
      company_directory_locations: SiteSetting.company_directory_locations,
      company_directory_categories: SiteSetting.company_directory_categories,
      company_directory_send_expiry_notifications: SiteSetting.company_directory_send_expiry_notifications,
      company_directory_send_reactivation_notifications: SiteSetting.company_directory_send_reactivation_notifications
    }
    
    respond_to do |format|
      format.html { render :settings }
      format.json { render json: { settings: @settings } }
    end
  end
  
  def update_settings
    settings_params.each do |key, value|
      if SiteSetting.respond_to?("#{key}=")
        SiteSetting.set(key, value)
      end
    end
    
    render json: {
      success: true,
      message: "Settings updated successfully"
    }
  rescue => e
    render json: {
      success: false,
      error: e.message
    }, status: 422
  end
  
  # Bulk actions
  def bulk_action
    action = params[:bulk_action]
    listing_ids = params[:listing_ids]
    
    return render json: { error: "No listings selected" }, status: 422 if listing_ids.blank?
    
    listings = BusinessListing.where(id: listing_ids)
    
    case action
    when 'approve'
      listings.update_all(approved: true)
      message = "#{listings.count} listings approved"
    when 'feature'
      listings.update_all(featured: true)
      message = "#{listings.count} listings featured"
    when 'unfeature'
      listings.update_all(featured: false)
      message = "#{listings.count} listings unfeatured"
    when 'activate'
      listings.update_all(is_active: true)
      message = "#{listings.count} listings activated"
    when 'deactivate'
      listings.update_all(is_active: false)
      message = "#{listings.count} listings deactivated"
    when 'delete'
      count = listings.count
      listings.destroy_all
      message = "#{count} listings deleted"
    else
      return render json: { error: "Invalid action" }, status: 422
    end
    
    render json: {
      success: true,
      message: message
    }
  end
  
  # Export listings to CSV
  def export_csv
    require 'csv'
    
    listings = BusinessListing.includes(:user).order(:created_at)
    
    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        'ID', 'Business Name', 'User', 'Email', 'City', 'Category',
        'Status', 'Featured', 'Approved', 'Views', 'Created At'
      ]
      
      listings.each do |listing|
        csv << [
          listing.id,
          listing.business_name,
          listing.user.username,
          listing.user.email,
          listing.city,
          listing.category,
          listing.is_active? ? 'Active' : 'Inactive',
          listing.featured? ? 'Yes' : 'No',
          listing.approved? ? 'Yes' : 'No',
          listing.views_count,
          listing.created_at.strftime('%Y-%m-%d %H:%M')
        ]
      end
    end
    
    send_data csv_data, 
              filename: "company_directory_export_#{Date.current.strftime('%Y%m%d')}.csv",
              type: 'text/csv',
              disposition: 'attachment'
  end
  
  # Analytics data
  def analytics
    # Listings by month
    listings_by_month = BusinessListing.group_by_month(:created_at, last: 12).count
    
    # Listings by city (top 20)
    listings_by_city = BusinessListing.group(:city).count.sort_by(&:last).reverse.first(20)
    
    # Listings by category (top 20)
    listings_by_category = BusinessListing.group(:category).count.sort_by(&:last).reverse.first(20)
    
    # Most viewed listings
    most_viewed = BusinessListing.visible.order(views_count: :desc).limit(10)
    
    render json: {
      listings_by_month: listings_by_month,
      listings_by_city: listings_by_city,
      listings_by_category: listings_by_category,
      most_viewed: serialize_listings(most_viewed)
    }
  end
  
  private
  
  def find_listing
    @listing = BusinessListing.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Listing not found" }, status: 404
  end
  
  def admin_listing_params
    params.require(:business_listing).permit(
      :business_name, :description, :city, :category,
      :website, :instagram, :facebook, :tiktok,
      :email, :phone, :is_active, :featured, :approved, :priority,
      images: [],
      packages: [:name, :description, :price]
    )
  end
  
  def settings_params
    params.require(:settings).permit(
      :company_directory_enabled,
      :company_directory_subscription_plan_id,
      :company_directory_auto_approve,
      :company_directory_max_images,
      :company_directory_show_in_sitemap,
      :company_directory_featured_limit,
      :company_directory_locations,
      :company_directory_categories,
      :company_directory_send_expiry_notifications,
      :company_directory_send_reactivation_notifications
    )
  end
  
  def serialize_listing(listing)
    {
      id: listing.id,
      business_name: listing.business_name,
      description: listing.description,
      city: listing.city,
      category: listing.category,
      slug: listing.slug,
      website: listing.website,
      email: listing.email,
      phone: listing.phone,
      is_active: listing.is_active?,
      featured: listing.featured?,
      approved: listing.approved?,
      priority: listing.priority,
      views_count: listing.views_count,
      user: {
        id: listing.user.id,
        username: listing.user.username,
        email: listing.user.email
      },
      created_at: listing.created_at,
      updated_at: listing.updated_at
    }
  end
  
  def serialize_listings(listings)
    listings.map { |listing| serialize_listing(listing) }
  end
end
