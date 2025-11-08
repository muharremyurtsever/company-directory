# frozen_string_literal: true

class CompanyDirectorySitemap
  def self.register!
    # Register with Discourse's sitemap system
    DiscourseEvent.on(:sitemap_updated) do
      generate_sitemap_entries
    end
  end

  def self.generate_sitemap_entries
    return unless SiteSetting.company_directory_enabled
    return unless SiteSetting.company_directory_show_in_sitemap

    sitemap_entries = []

    # Add main directory page
    sitemap_entries << {
      url: "/directory",
      priority: 0.8,
      changefreq: "weekly",
      lastmod: BusinessListing.maximum(:updated_at)&.iso8601
    }

    # Add city-category pages
    BusinessListing.city_category_combinations.each do |city, category|
      city_category_slug = "#{city.downcase.gsub(/[^a-z0-9]+/, '-')}-#{category.downcase.gsub(/[^a-z0-9]+/, '-')}-photographers"
      
      # Get the latest update for this combination
      last_update = BusinessListing.for_seo_page(city, category).maximum(:updated_at)
      
      sitemap_entries << {
        url: "/directory/#{city_category_slug}",
        priority: 0.7,
        changefreq: "weekly",
        lastmod: last_update&.iso8601
      }
    end

    # Add individual business profiles
    BusinessListing.visible.find_each do |listing|
      sitemap_entries << {
        url: listing.profile_url,
        priority: 0.6,
        changefreq: "monthly",
        lastmod: listing.updated_at.iso8601
      }
    end

    # Store entries for sitemap generation
    Rails.cache.write('company_directory_sitemap_entries', sitemap_entries, expires_in: 1.week)
    
    sitemap_entries
  end

  def self.get_sitemap_entries
    Rails.cache.fetch('company_directory_sitemap_entries', expires_in: 1.week) do
      generate_sitemap_entries
    end
  end

  def self.sitemap_xml
    entries = get_sitemap_entries
    
    xml = '<?xml version="1.0" encoding="UTF-8"?>' + "\n"
    xml += '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">' + "\n"
    
    entries.each do |entry|
      xml += "  <url>\n"
      xml += "    <loc>#{Discourse.base_url}#{entry[:url]}</loc>\n"
      xml += "    <lastmod>#{entry[:lastmod]}</lastmod>\n" if entry[:lastmod]
      xml += "    <changefreq>#{entry[:changefreq]}</changefreq>\n" if entry[:changefreq]
      xml += "    <priority>#{entry[:priority]}</priority>\n" if entry[:priority]
      xml += "  </url>\n"
    end
    
    xml += '</urlset>'
    xml
  end

  def self.ping_search_engines
    return unless Rails.env.production?
    return unless SiteSetting.company_directory_enabled

    sitemap_url = "#{Discourse.base_url}/company-directory-sitemap.xml"
    
    # Ping Google
    begin
      Net::HTTP.get(URI("http://www.google.com/ping?sitemap=#{CGI.escape(sitemap_url)}"))
    rescue => e
      Rails.logger.warn "Failed to ping Google with sitemap: #{e.message}"
    end

    # Ping Bing
    begin
      Net::HTTP.get(URI("http://www.bing.com/ping?sitemap=#{CGI.escape(sitemap_url)}"))
    rescue => e
      Rails.logger.warn "Failed to ping Bing with sitemap: #{e.message}"
    end
  end
end
