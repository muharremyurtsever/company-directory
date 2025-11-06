# frozen_string_literal: true

module Jobs
  class ReactivateRenewedListings < ::Jobs::Scheduled
    every 1.day
    
    def execute(args)
      return unless SiteSetting.company_directory_enabled
      return unless defined?(DiscourseSubscriptions)
      
      plan_id = SiteSetting.company_directory_subscription_plan_id
      return if plan_id.blank?
      
      reactivated_count = 0
      
      # Find all inactive listings where user now has active subscription
      BusinessListing.inactive.includes(:user).each do |listing|
        if listing.user_has_active_subscription?
          listing.update!(is_active: true)
          reactivated_count += 1
          
          # Optionally send welcome back notification
          send_reactivation_notification(listing.user, listing) if SiteSetting.company_directory_send_reactivation_notifications
        end
      end
      
      Rails.logger.info "[CompanyDirectory] Reactivated #{reactivated_count} renewed listings"
      
      # Update site statistics
      if reactivated_count > 0
        DiscourseEvent.trigger(:company_directory_listings_reactivated, reactivated_count)
      end
    end
    
    private
    
    def send_reactivation_notification(user, listing)
      # Create a system message to notify the user
      SystemMessage.create_from_system_user(
        user,
        :company_directory_listing_reactivated,
        {
          business_name: listing.business_name,
          listing_url: "#{Discourse.base_url}#{listing.profile_url}",
          manage_url: "#{Discourse.base_url}/my-business"
        }
      )
    rescue => e
      Rails.logger.error "[CompanyDirectory] Failed to send reactivation notification to user #{user.id}: #{e.message}"
    end
  end
end