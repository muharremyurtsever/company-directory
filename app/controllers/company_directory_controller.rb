# frozen_string_literal: true

class CompanyDirectoryController < ApplicationController
  requires_plugin 'discourse-company-directory'
  
  before_action :ensure_logged_in, only: [:my_business, :create_business, :update_business, :delete_business]
  before_action :ensure_directory_enabled
  before_action :find_business_listing, only: [:update_business, :delete_business]
  before_action :ensure_can_manage_listing, only: [:update_business, :delete_business]
  
  def index
    @cities = SiteSetting.company_directory_locations.split("\n").map(&:strip).sort
    @categories = SiteSetting.company_directory_categories.split("\n").map(&:strip).sort
    
    # Get filter params
    city_filter = params[:city]
    category_filter = params[:category]
    search_query = params[:search]
    page = [params[:page].to_i, 1].max
    per_page = 20
    
    # Build query
    listings = BusinessListing.visible.includes(:user)
    listings = listings.by_city(city_filter) if city_filter.present?
    listings = listings.by_category(category_filter) if category_filter.present?
    listings = listings.search(search_query) if search_query.present?
    
    # Order and paginate
    @listings = listings.ordered_for_display
                       .offset((page - 1) * per_page)
                       .limit(per_page)
    
    @total_count = listings.count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_more = page < @total_pages
    
    # For SEO
    @page_title = "UK Photography Directory | ThePhotographers.uk"
    @page_description = "Find professional photographers across the UK. Browse portfolios, compare services, and connect with local photography experts."
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          listings: @listings.map { |listing| serialize_listing(listing) },
          pagination: {
            current_page: @current_page,
            total_pages: @total_pages,
            total_count: @total_count,
            has_more: @has_more
          },
          filters: {
            cities: @cities,
            categories: @categories
          }
        }
      end
    end
  end
  
  def city_category_page
    # Parse the city-category from URL
    city_category = params[:city_category]
    
    # Split city and category (last part after last dash should be "photographers")
    parts = city_category.split('-')
    return render_404 if parts.length < 3 || parts.last != 'photographers'
    
    # Remove "photographers" from the end
    parts.pop
    
    # Last part is the category (might be multi-word)
    category_parts = []
    city_parts = []
    
    # Find where category starts (look for known categories)
    allowed_categories = SiteSetting.company_directory_categories.split("\n").map(&:strip)
    category_found = false
    
    parts.reverse.each do |part|
      if category_found
        city_parts.unshift(part)
      else
        category_parts.unshift(part)
        potential_category = category_parts.join(' ').titleize
        if allowed_categories.include?(potential_category)
          category_found = true
        end
      end
    end
    
    return render_404 unless category_found
    
    @city = city_parts.join(' ').titleize
    @category = category_parts.join(' ').titleize
    
    # Validate city and category
    allowed_cities = SiteSetting.company_directory_locations.split("\n").map(&:strip)
    return render_404 unless allowed_cities.include?(@city)
    return render_404 unless allowed_categories.include?(@category)
    
    # Get listings for this city/category
    page = [params[:page].to_i, 1].max
    per_page = 20
    
    @listings = BusinessListing.for_seo_page(@city, @category)
                              .includes(:user)
                              .ordered_for_display
                              .offset((page - 1) * per_page)
                              .limit(per_page)
    
    @total_count = BusinessListing.for_seo_page(@city, @category).count
    @current_page = page
    @total_pages = (@total_count.to_f / per_page).ceil
    @has_more = page < @total_pages
    
    # SEO data
    category_lower = @category.downcase
    @page_title = "#{@city} #{@category}s | ThePhotographers.uk"
    @page_description = "Find the best #{category_lower}s in #{@city}. Browse portfolios, compare packages, and contact local photography professionals."
    @canonical_url = request.original_url.split('?').first
    
    respond_to do |format|
      format.html { render :city_category_page }
      format.json do
        render json: {
          city: @city,
          category: @category,
          listings: @listings.map { |listing| serialize_listing(listing) },
          pagination: {
            current_page: @current_page,
            total_pages: @total_pages,
            total_count: @total_count,
            has_more: @has_more
          },
          seo: {
            title: @page_title,
            description: @page_description,
            canonical_url: @canonical_url
          }
        }
      end
    end
  end
  
  def business_profile
    city_category = params[:city_category]
    slug = params[:slug]
    
    @listing = BusinessListing.visible.find_by(slug: slug)
    return render_404 unless @listing
    
    # Verify the URL matches the business
    expected_city_category = @listing.city_category_slug
    return redirect_to(@listing.profile_url, status: 301) if city_category != expected_city_category
    
    # Increment view count
    @listing.increment_views!
    
    # SEO data
    @page_title = @listing.seo_title
    @page_description = @listing.seo_description
    @canonical_url = request.original_url.split('?').first
    
    # Related listings
    @related_listings = BusinessListing.for_seo_page(@listing.city, @listing.category)
                                      .where.not(id: @listing.id)
                                      .includes(:user)
                                      .ordered_for_display
                                      .limit(6)
    
    respond_to do |format|
      format.html { render :business_profile }
      format.json do
        render json: {
          listing: serialize_listing_detailed(@listing),
          related_listings: @related_listings.map { |listing| serialize_listing(listing) },
          seo: {
            title: @page_title,
            description: @page_description,
            canonical_url: @canonical_url
          }
        }
      end
    end
  end
  
  def my_business
    @listing = current_user.business_listings.active.first
    @can_create = current_user.can_create_business_listing?
    
    @cities = SiteSetting.company_directory_locations.split("\n").map(&:strip).sort
    @categories = SiteSetting.company_directory_categories.split("\n").map(&:strip).sort
    @max_images = SiteSetting.company_directory_max_images
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          listing: @listing ? serialize_listing_detailed(@listing) : nil,
          can_create: @can_create,
          config: {
            cities: @cities,
            categories: @categories,
            max_images: @max_images
          }
        }
      end
    end
  end
  
  def create_business
    unless current_user.can_create_business_listing?
      return render json: { error: I18n.t("company_directory.no_subscription") }, status: 403
    end
    
    # Check if user already has an active listing
    existing_listing = current_user.business_listings.active.first
    if existing_listing
      return render json: { error: "You already have an active business listing" }, status: 422
    end
    
    @listing = current_user.business_listings.build(listing_params)
    @listing.approved = SiteSetting.company_directory_auto_approve
    
    if @listing.save
      render json: {
        success: true,
        message: I18n.t("company_directory.listing_created"),
        listing: serialize_listing_detailed(@listing)
      }
    else
      render json: {
        success: false,
        errors: @listing.errors.full_messages
      }, status: 422
    end
  end
  
  def update_business
    @listing.assign_attributes(listing_params)
    
    if @listing.save
      render json: {
        success: true,
        message: I18n.t("company_directory.listing_updated"),
        listing: serialize_listing_detailed(@listing)
      }
    else
      render json: {
        success: false,
        errors: @listing.errors.full_messages
      }, status: 422
    end
  end
  
  def delete_business
    @listing.destroy!
    
    render json: {
      success: true,
      message: I18n.t("company_directory.listing_deleted")
    }
  end
  
  private
  
  def ensure_directory_enabled
    unless SiteSetting.company_directory_enabled
      return render_404
    end
  end
  
  def find_business_listing
    @listing = current_user.business_listings.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Listing not found" }, status: 404
  end
  
  def ensure_can_manage_listing
    unless @listing&.user == current_user || current_user.staff?
      render json: { error: "Unauthorized" }, status: 403
    end
  end
  
  def listing_params
    params.require(:business_listing).permit(
      :business_name, :description, :city, :category,
      :website, :instagram, :facebook, :tiktok,
      :email, :phone,
      images: [],
      packages: [:name, :description, :price]
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
      profile_url: listing.profile_url,
      website: listing.website,
      featured: listing.featured?,
      image_urls: listing.image_urls.first(3), # Show max 3 in listing view
      user: {
        id: listing.user.id,
        username: listing.user.username,
        avatar_template: listing.user.avatar_template
      },
      created_at: listing.created_at,
      views_count: listing.views_count
    }
  end
  
  def serialize_listing_detailed(listing)
    {
      id: listing.id,
      business_name: listing.business_name,
      description: listing.description,
      city: listing.city,
      category: listing.category,
      slug: listing.slug,
      profile_url: listing.profile_url,
      website: listing.website,
      instagram: listing.instagram,
      facebook: listing.facebook,
      tiktok: listing.tiktok,
      email: listing.email,
      phone: listing.phone,
      featured: listing.featured?,
      image_urls: listing.image_urls,
      packages: listing.formatted_packages,
      social_links: listing.social_links,
      contact_methods: listing.contact_methods,
      user: {
        id: listing.user.id,
        username: listing.user.username,
        avatar_template: listing.user.avatar_template
      },
      created_at: listing.created_at,
      views_count: listing.views_count,
      is_active: listing.is_active?,
      approved: listing.approved?
    }
  end
  
  def render_404
    raise ActionController::RoutingError.new('Not Found')
  end
end