# frozen_string_literal: true

# name: company-directory
# about: UK Company Directory Plugin with Paid Subscription Integration and SEO Pages (Discourse 2025 / Rails 8 Compatible)
# version: 2.0.0
# authors: ThePhotographers.uk Team
# url: https://github.com/muharremyurtsever/company-directory
# required_version: 3.3.0
# transpile_js: true

module ::CompanyDirectory
  PLUGIN_NAME = "company-directory"
  PLUGIN_ROOT = File.expand_path(__dir__)
end

enabled_site_setting :company_directory_enabled

register_asset 'stylesheets/company-directory.scss'
register_svg_icon "fab-instagram"
register_svg_icon "fab-facebook"
register_svg_icon "fab-tiktok"
register_svg_icon "globe"

after_initialize do
  # ==================================================================================
  # DISCOURSE 2025 / RAILS 8 COMPATIBLE PLUGIN
  # ==================================================================================
  # This plugin uses SERVER-SIDE RENDERING (ERB templates) with proper XHR skip
  # All controllers have `skip_before_action :check_xhr` for HTML routes
  # This is the modern approach for Discourse 2025 plugins that need SEO pages
  # ==================================================================================

  # Load plugin files
  Dir.glob(File.join(::CompanyDirectory::PLUGIN_ROOT, "app/**/*.rb")).each { |f| load f }
  Dir.glob(File.join(::CompanyDirectory::PLUGIN_ROOT, "lib/**/*.rb")).each { |f| load f }

  # Register view paths so Discourse can find our templates
  ActionController::Base.prepend_view_path(File.join(::CompanyDirectory::PLUGIN_ROOT, "app/views"))

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
      post '/company-directory/uploads' => 'company_directory#upload_image'
    end

    get '/company-directory-sitemap' => 'company_directory/sitemap#company_directory', defaults: { format: :xml }
    
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

    # Staff bypass for testing and administration
    return true if self.staff?

    # Check if user has active subscription
    if defined?(DiscourseSubscriptions)
      plan_id = SiteSetting.company_directory_subscription_plan_id
      return false if plan_id.blank?

      subscriptions = DiscourseSubscriptions::Subscription
                        .joins(:customer)
                        .where(discourse_subscriptions_customers: { user_id: self.id })
                        .where(status: 'active')
                        .where(plan_id: plan_id)

      return subscriptions.exists?
    end

    # Fallback: check if user is in a specific group
    false
  end

  # Register scheduled jobs
  # NOTE: Scheduled jobs are registered in their respective job classes
  # (app/jobs/scheduled/*.rb) using the `every` method within the job class itself
  # The inline `every` syntax here is deprecated in modern Discourse versions

  # Admin menu integration disabled - requires proper Ember.js admin route setup
  # For admin management, access /admin/plugins/company-directory directly via custom routes
  # add_admin_route 'company_directory.title', 'company-directory'

  # Register serializer modifications
  add_to_serializer(:current_user, :can_create_business_listing) do
    next unless object.is_a?(User)
    object.can_create_business_listing?
  end

  add_to_serializer(:current_user, :business_listing) do
    next unless object.is_a?(User)
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
    # Include helper in ApplicationController so it's available in all views
    ApplicationController.class_eval do
      helper CompanyDirectoryHelper
    end

    User.class_eval do
      has_many :business_listings, dependent: :destroy
    end
  end
end

# CSS is now in assets/stylesheets/company-directory.scss
# This provides better theme integration and dark mode support
