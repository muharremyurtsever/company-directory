# frozen_string_literal: true

module Jobs
  class UpdateSitemapEntries < ::Jobs::Scheduled
    every 1.week
    
    def execute(args)
      return unless SiteSetting.company_directory_enabled
      return unless SiteSetting.company_directory_show_in_sitemap
      
      added_count = 0
      
      # Get existing sitemap entries to avoid duplicates
      existing_urls = get_existing_sitemap_urls
      
      # Add main directory page
      main_url = "/directory"
      unless existing_urls.include?(main_url)
        add_sitemap_entry(main_url, priority: 0.8, changefreq: 'weekly')
        added_count += 1
      end
      
      # Add city-category pages
      combinations = BusinessListing.city_category_combinations
      
      combinations.each do |city, category|
        city_category_slug = "#{city.downcase.gsub(/[^a-z0-9]+/, '-')}-#{category.downcase.gsub(/[^a-z0-9]+/, '-')}-photographers"
        url = "/directory/#{city_category_slug}"
        
        unless existing_urls.include?(url)
          add_sitemap_entry(url, priority: 0.7, changefreq: 'weekly')
          added_count += 1
        end
      end
      
      # Add individual business profile pages
      BusinessListing.visible.find_each do |listing|
        url = listing.profile_url
        
        unless existing_urls.include?(url)
          add_sitemap_entry(url, priority: 0.6, changefreq: 'monthly', lastmod: listing.updated_at)
          added_count += 1
        end
      end
      
      Rails.logger.info "[CompanyDirectory] Added #{added_count} URLs to sitemap"
      
      # Trigger sitemap regeneration if needed
      if added_count > 0 && defined?(SitemapGenerator)
        SitemapGenerator::Sitemap.ping_search_engines
      end
    end
    
    private
    
    def get_existing_sitemap_urls
      # This would depend on how Discourse handles sitemaps
      # For now, we'll use a simple cache-based approach
      Rails.cache.fetch('company_directory_sitemap_urls', expires_in: 1.day) { [] }
    end
    
    def add_sitemap_entry(url, priority: 0.5, changefreq: 'monthly', lastmod: nil)
      # Store sitemap entries in cache or database
      existing_urls = Rails.cache.fetch('company_directory_sitemap_urls', expires_in: 1.day) { [] }
      
      entry = {
        url: url,
        priority: priority,
        changefreq: changefreq,
        lastmod: lastmod || Time.current
      }
      
      existing_urls << url unless existing_urls.include?(url)
      Rails.cache.write('company_directory_sitemap_urls', existing_urls, expires_in: 1.day)
      
      # If using a custom sitemap handler, add the entry there
      add_to_discourse_sitemap(entry) if respond_to?(:add_to_discourse_sitemap)
    end
    
    def add_to_discourse_sitemap(entry)
      # Integration with Discourse's sitemap system
      # This would need to be implemented based on Discourse's current sitemap architecture
      begin
        DiscourseEvent.trigger(:sitemap_entry_added, entry)
      rescue => e
        Rails.logger.debug "[CompanyDirectory] Sitemap integration not available: #{e.message}"
      end
    end
  end
end