# frozen_string_literal: true

require_dependency "upload_creator"
require_dependency "upload_reference"

class CompanyDirectoryController < ApplicationController
  requires_plugin 'company-directory'

  # CRITICAL: Allow non-XHR requests for HTML rendering (Discourse 2025/Rails 8 compatibility)
  skip_before_action :check_xhr, only: [:index, :city_category_page, :business_profile, :my_business]
  skip_before_action :preload_json, only: [:index, :city_category_page, :business_profile, :my_business]
  skip_before_action :redirect_to_login_if_required, only: [:index, :city_category_page, :business_profile]

  before_action :ensure_logged_in, only: [:my_business, :create_business, :update_business, :delete_business, :upload_image]
  before_action :ensure_directory_enabled
  before_action :find_business_listing, only: [:update_business, :delete_business]
  before_action :ensure_can_manage_listing, only: [:update_business, :delete_business]
  
  def index
    @cities = available_cities.sort
    @categories = available_categories.sort
    
    # Get filter params
    city_filter = params[:city]
    category_filter = params[:category]
    search_query = params[:search]
    page = [params[:page].to_i, 1].max
    per_page = 20
    @selected_city = city_filter.presence
    @selected_category = category_filter.presence
    @search_query = search_query
    
    # Build query
    listings = BusinessListing.visible.includes(:user)
    listings = listings.by_city(city_filter) if city_filter.present?
    listings = listings.by_category(category_filter) if category_filter.present?
    listings = listings.search(search_query) if search_query.present?
    
    # Order and paginate
    @listings = listings.ordered_for_display
                       .offset((page - 1) * per_page)
                       .limit(per_page)
                       .to_a
    
    @total_count = listings.count
    @current_page = page
    @total_pages = [(@total_count.to_f / per_page).ceil, 1].max
    @has_more = page < @total_pages
    @featured_limit = SiteSetting.company_directory_featured_limit
    
    # For SEO
    @page_title = "UK Photography Directory | ThePhotographers.uk"
    @page_description = "Find professional photographers across the UK. Browse portfolios, compare services, and connect with local photography experts."
    @canonical_url = request.original_url.split('?').first
    
    respond_to do |format|
      format.html { render "default/empty", layout: "application" }
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
    allowed_categories = available_categories
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
    allowed_cities = available_cities
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
                              .to_a
    
    @total_count = BusinessListing.for_seo_page(@city, @category).count
    @current_page = page
    @total_pages = [(@total_count.to_f / per_page).ceil, 1].max
    @has_more = page < @total_pages
    
    # SEO data
    category_lower = @category.downcase
    @page_title = "#{@city} #{@category}s | ThePhotographers.uk"
    @page_description = "Find the best #{category_lower}s in #{@city}. Browse portfolios, compare packages, and contact local photography professionals."
    @canonical_url = request.original_url.split('?').first
    
    respond_to do |format|
      format.html { render :city_category_page, layout: "application" }
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
      format.html { render :business_profile, layout: "application" }
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

    @cities = available_cities.sort
    @categories = available_categories.sort
    @max_images = SiteSetting.company_directory_max_images

    respond_to do |format|
      format.html { render "default/empty", layout: "application" }
      format.json do
        render json: {
          listing: @listing ? serialize_listing_detailed(@listing) : nil,
          has_listing: @listing.present?,
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
    
    permitted_params = listing_params
    image_payload = permitted_params.delete(:images)
    @listing = current_user.business_listings.build(permitted_params)
    apply_listing_images(@listing, image_payload)
    @listing.approved = SiteSetting.company_directory_auto_approve

    if @listing.save
      sync_listing_uploads(@listing)
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
    permitted_params = listing_params
    image_payload = permitted_params.delete(:images)
    @listing.assign_attributes(permitted_params)
    apply_listing_images(@listing, image_payload)

    if @listing.save
      sync_listing_uploads(@listing)
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

  def upload_image
    unless current_user.can_create_business_listing?
      return render json: { error: I18n.t("company_directory.no_subscription") }, status: 403
    end

    # Rate limiting to prevent spam uploads
    RateLimiter.new(current_user, "company_directory_upload", 10, 1.minute).performed!

    uploads = Array.wrap(params[:files] || params[:file]).compact
    raise Discourse::InvalidParameters.new(:file) if uploads.blank?

    created_uploads = uploads.map do |uploaded_file|
      upload = UploadCreator.new(uploaded_file, uploaded_file.original_filename, type: "company_directory").create_for(current_user.id)

      if upload.errors.present?
        raise Discourse::InvalidParameters.new(upload.errors.full_messages.join(", "))
      end

      {
        id: upload.id,
        url: upload.url,
        original_filename: upload.original_filename,
        width: upload.width,
        height: upload.height
      }
    end

    render json: { uploads: created_uploads }
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
    return false
  end

  def ensure_can_manage_listing
    unless @listing&.user == current_user || current_user.staff?
      render json: { error: "Unauthorized" }, status: 403
      return false
    end
  end
  
  def listing_params
    params.require(:business_listing).permit(
      :business_name, :description, :city, :category,
      :website, :instagram, :facebook, :tiktok,
      :email, :phone,
      images: [:upload_id],
      packages: [:name, :description, :price]
    )
  end

  def apply_listing_images(listing, image_payload)
    return if image_payload.nil?

    listing.images = normalized_images(image_payload)
  end

  def normalized_images(image_payload)
    normalized_payload = image_payload.first(SiteSetting.company_directory_max_images)
    upload_ids = normalized_payload.map { |image| image[:upload_id] || image["upload_id"] }.compact
    return [] if upload_ids.blank?

    uploads = Upload.where(id: upload_ids).index_by(&:id)

    normalized_payload.map do |image|
      upload = uploads[image[:upload_id]&.to_i || image["upload_id"]&.to_i]
      next unless upload

      {
        "upload_id" => upload.id,
        "url" => upload.url,
        "original_filename" => upload.original_filename,
        "width" => upload.width,
        "height" => upload.height
      }
    end.compact
  end

  def sync_listing_uploads(listing)
    upload_ids = Array.wrap(listing.images).map { |image| image["upload_id"] }.compact

    if upload_ids.empty?
      UploadReference.where(target: listing).destroy_all
      return
    end

    UploadReference.where(target: listing).where.not(upload_id: upload_ids).destroy_all

    upload_ids.each do |upload_id|
      UploadReference.find_or_create_by!(target: listing, upload_id: upload_id) do |ref|
        ref.user_id = listing.user_id
        ref.origin = "company_directory"
      end
    end
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
      approved: listing.approved?,
      has_listing: true,
      images: listing.images || []
    }
  end
  
  def render_404
    raise ActionController::RoutingError.new('Not Found')
  end

  def available_cities
    @available_cities ||= normalized_setting_list(SiteSetting.company_directory_locations)
  end

  def available_categories
    @available_categories ||= normalized_setting_list(SiteSetting.company_directory_categories)
  end

  def normalized_setting_list(raw_value)
    raw_value.to_s.split("\n").map { |item| item.strip.presence }.compact.uniq
  end
end
