# frozen_string_literal: true

module Jobs
  class GenerateCityCategoryPages < ::Jobs::Scheduled
    every 1.week
    
    def execute(args)
      return unless SiteSetting.company_directory_enabled
      return unless SiteSetting.company_directory_show_in_sitemap
      
      generated_count = 0
      
      # Get all city-category combinations that have active listings
      combinations = BusinessListing.city_category_combinations
      
      combinations.each do |city, category|
        # Generate/update the page data
        page_data = generate_page_data(city, category)
        
        # Store or update in cache/database if needed
        cache_key = "company_directory_page:#{city.downcase.gsub(/[^a-z0-9]/, '-')}-#{category.downcase.gsub(/[^a-z0-9]/, '-')}"
        Rails.cache.write(cache_key, page_data, expires_in: 1.week)
        
        generated_count += 1
      end
      
      Rails.logger.info "[CompanyDirectory] Generated #{generated_count} city-category pages"
      
      # Trigger sitemap update
      Jobs.enqueue(:update_sitemap_entries) if generated_count > 0
    end
    
    private
    
    def generate_page_data(city, category)
      listings_count = BusinessListing.for_seo_page(city, category).count
      featured_count = BusinessListing.for_seo_page(city, category).featured.count
      
      city_category_slug = "#{city.downcase.gsub(/[^a-z0-9]+/, '-')}-#{category.downcase.gsub(/[^a-z0-9]+/, '-')}-photographers"
      
      {
        city: city,
        category: category,
        slug: city_category_slug,
        url: "/directory/#{city_category_slug}",
        title: "#{city} #{category}s | ThePhotographers.uk",
        description: "Find the best #{category.downcase}s in #{city}. Browse portfolios, compare packages, and contact local photography professionals.",
        listings_count: listings_count,
        featured_count: featured_count,
        last_updated: Time.current,
        schema_data: generate_schema_data(city, category, listings_count)
      }
    end
    
    def generate_schema_data(city, category, listings_count)
      {
        "@context": "https://schema.org",
        "@type": "CollectionPage",
        "name": "#{city} #{category}s",
        "description": "Directory of professional #{category.downcase}s in #{city}",
        "url": "#{Discourse.base_url}/directory/#{city.downcase.gsub(/[^a-z0-9]+/, '-')}-#{category.downcase.gsub(/[^a-z0-9]+/, '-')}-photographers",
        "numberOfItems": listings_count,
        "provider": {
          "@type": "Organization",
          "name": "ThePhotographers.uk",
          "url": Discourse.base_url
        },
        "geo": {
          "@type": "Place",
          "name": city,
          "addressLocality": city,
          "addressCountry": "GB"
        }
      }
    end
  end
end