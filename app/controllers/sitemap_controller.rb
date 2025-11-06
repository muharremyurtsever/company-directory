# frozen_string_literal: true

class SitemapController < ApplicationController
  requires_plugin 'discourse-company-directory'
  
  skip_before_action :check_xhr, :redirect_to_login_if_required
  
  def company_directory
    unless SiteSetting.company_directory_enabled && SiteSetting.company_directory_show_in_sitemap
      return render plain: "Sitemap disabled", status: 404
    end

    sitemap_xml = CompanyDirectorySitemap.sitemap_xml
    
    respond_to do |format|
      format.xml { render xml: sitemap_xml }
    end
  end
end