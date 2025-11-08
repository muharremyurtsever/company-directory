# frozen_string_literal: true

# name: company-directory
# about: UK Company Directory Plugin with Paid Subscription Integration and SEO Pages
# meta_topic_id: TODO
# version: 1.0.0
# authors: ThePhotographers.uk Team
# url: https://github.com/trbozo/company-directory
# required_version: 3.3.0
# transpile_js: true

module ::CompanyDirectory
  PLUGIN_NAME = "company-directory"
  PLUGIN_ROOT = File.expand_path(__dir__)
end

gem "mini_magick", "~> 4.12"
gem "image_processing", "1.12.2"

enabled_site_setting :company_directory_enabled

register_asset 'stylesheets/company-directory.scss'

after_initialize do
  # Load plugin files
  Dir.glob(File.join(::CompanyDirectory::PLUGIN_ROOT, "app/**/*.rb")).each { |f| load f }
  Dir.glob(File.join(::CompanyDirectory::PLUGIN_ROOT, "lib/**/*.rb")).each { |f| load f }
  
  # Add custom routes
  directory_constraint = ->(_request) { SiteSetting.company_directory_enabled }

  directory_routes = proc do
    constraints(directory_constraint) do
      get '/directory' => 'company_directory#index'
      get '/directory/:city_category' => 'company_directory#city_category_page', constraints: { city_category: /[^\/]+/ }
      get '/directory/:city_category/:slug' => 'company_directory#business_profile', constraints: { city_category: /[^\/]+/, slug: /[^\/]+/ }
      get '/my-business' => 'company_directory#my_business'
      post '/my-business' => 'company_directory#create_business'
      put '/my-business/:id' => 'company_directory#update_business'
      delete '/my-business/:id' => 'company_directory#delete_business'
    end

    get '/company-directory-sitemap' => 'sitemap#company_directory', defaults: { format: :xml }
    
    # Admin routes
    scope '/admin/plugins' do
      get '/company-directory' => 'admin/company_directory#index'
      get '/company-directory/listings' => 'admin/company_directory#listings'
      put '/company-directory/listings/:id' => 'admin/company_directory#update_listing'
      delete '/company-directory/listings/:id' => 'admin/company_directory#delete_listing'
      get '/company-directory/settings' => 'admin/company_directory#settings'
      put '/company-directory/settings' => 'admin/company_directory#update_settings'
    end
  end
  Discourse::Application.routes.prepend(&directory_routes)

  if respond_to?(:register_sitemap_generator)
    register_sitemap_generator("company_directory") do |sitemap|
      CompanyDirectorySitemap.generate_sitemap_entries.each do |entry|
        loc = "#{Discourse.base_url}#{entry[:url]}"
        sitemap.add(
          loc,
          priority: entry[:priority],
          changefreq: entry[:changefreq],
          lastmod: entry[:lastmod]
        )
      end
    end
  elsif defined?(CompanyDirectorySitemap)
    CompanyDirectorySitemap.register!
  end

  # Add navigation item for logged-in users
  add_to_class(:user, :can_create_business_listing?) do
    return false unless SiteSetting.company_directory_enabled
    
    # Check if user has active subscription
    if defined?(DiscourseSubscriptions)
      plan_id = SiteSetting.company_directory_subscription_plan_id
      return false if plan_id.blank?
      
      subscriptions = DiscourseSubscriptions::Customer.where(user_id: self.id)
                        .joins("JOIN discourse_subscriptions_subscriptions ON discourse_subscriptions_customers.id = discourse_subscriptions_subscriptions.customer_id")
                        .where("discourse_subscriptions_subscriptions.status = 'active'")
      
      return subscriptions.exists?
    end
    
    # Fallback: check if user is in a specific group
    false
  end

  # Register scheduled jobs
  if Rails.env.production?
    every(1.day) do
      Jobs.enqueue(:deactivate_expired_listings)
      Jobs.enqueue(:reactivate_renewed_listings)
    end
    
    every(1.week) do
      Jobs.enqueue(:generate_city_category_pages)
      Jobs.enqueue(:update_sitemap_entries)
    end
  end

  # Add to admin menu
  add_admin_route 'company_directory.title', 'company-directory'

  # Register serializer modifications
  add_to_serializer(:current_user, :can_create_business_listing) do
    object.can_create_business_listing?
  end

  add_to_serializer(:current_user, :business_listing) do
    if object.can_create_business_listing?
      listing = BusinessListing.where(user_id: object.id, is_active: true).first
      if listing
        {
          id: listing.id,
          business_name: listing.business_name,
          city: listing.city,
          category: listing.category,
          has_listing: true
        }
      else
        { has_listing: false }
      end
    end
  end

  # Hook into subscription events if DiscourseSubscriptions is available
  if defined?(DiscourseSubscriptions)
    on(:subscription_created) do |subscription, user|
      # Activate any existing inactive listings for this user
      BusinessListing.where(user_id: user.id, is_active: false)
                    .update_all(is_active: true, updated_at: Time.current)
    end

    on(:subscription_cancelled) do |subscription, user|
      # Deactivate all listings for this user
      BusinessListing.where(user_id: user.id, is_active: true)
                    .update_all(is_active: false, updated_at: Time.current)
    end
  end

  reloadable_patch do
    User.class_eval do
      has_many :business_listings, dependent: :destroy
    end
  end
end

# Register CSS
register_css <<~CSS
  .company-directory-container {
    max-width: 1200px;
    margin: 0 auto;
    padding: 20px;
  }

  .business-listing-card {
    border: 1px solid var(--primary-low);
    border-radius: 8px;
    padding: 20px;
    margin-bottom: 20px;
    background: var(--secondary);
  }

  .business-listing-card.featured {
    border-color: var(--tertiary);
    background: var(--tertiary-low);
  }

  .business-listing-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 15px;
  }

  .business-listing-title {
    font-size: 1.5em;
    font-weight: bold;
    color: var(--primary);
    margin: 0;
  }

  .business-listing-category {
    font-size: 0.9em;
    color: var(--primary-medium);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }

  .business-listing-description {
    margin: 15px 0;
    line-height: 1.6;
  }

  .business-listing-meta {
    display: flex;
    gap: 15px;
    margin-top: 15px;
    font-size: 0.9em;
  }

  .business-listing-images {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
    gap: 10px;
    margin: 15px 0;
  }

  .business-listing-image {
    width: 100%;
    height: 120px;
    object-fit: cover;
    border-radius: 4px;
  }

  .directory-filters {
    display: flex;
    gap: 15px;
    margin-bottom: 30px;
    flex-wrap: wrap;
  }

  .directory-filter-select {
    min-width: 150px;
  }

  .my-business-form {
    max-width: 800px;
    margin: 0 auto;
  }

  .form-row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 20px;
    margin-bottom: 20px;
  }

  .form-row.full-width {
    grid-template-columns: 1fr;
  }

  .package-item {
    border: 1px solid var(--primary-low);
    border-radius: 4px;
    padding: 15px;
    margin-bottom: 10px;
  }

  .image-upload-area {
    border: 2px dashed var(--primary-low);
    border-radius: 8px;
    padding: 30px;
    text-align: center;
    margin: 20px 0;
  }

  .uploaded-images {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
    gap: 15px;
    margin-top: 20px;
  }

  .uploaded-image {
    position: relative;
  }

  .uploaded-image img {
    width: 100%;
    height: 150px;
    object-fit: cover;
    border-radius: 4px;
  }

  .remove-image {
    position: absolute;
    top: 5px;
    right: 5px;
    background: rgba(0,0,0,0.7);
    color: white;
    border: none;
    border-radius: 50%;
    width: 25px;
    height: 25px;
    cursor: pointer;
  }

  @media (max-width: 768px) {
    .form-row {
      grid-template-columns: 1fr;
    }
    
    .directory-filters {
      flex-direction: column;
    }
    
    .business-listing-meta {
      flex-direction: column;
      gap: 8px;
    }
  }
CSS
