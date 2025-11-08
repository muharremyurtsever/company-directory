# frozen_string_literal: true

module Jobs
  class UpdateSitemapEntries < ::Jobs::Scheduled
    every 1.week
    
    def execute(args)
      return unless SiteSetting.company_directory_enabled
      return unless SiteSetting.company_directory_show_in_sitemap
      return unless defined?(CompanyDirectorySitemap)

      CompanyDirectorySitemap.generate_sitemap_entries
      CompanyDirectorySitemap.ping_search_engines
    end
  end
end
