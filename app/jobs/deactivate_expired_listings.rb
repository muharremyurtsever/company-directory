# frozen_string_literal: true

module Jobs
  class DeactivateExpiredListings < ::Jobs::Scheduled
    every 1.day
    
    def execute(args)
      return unless SiteSetting.company_directory_enabled
      return unless defined?(DiscourseSubscriptions)
      
      plan_id = SiteSetting.company_directory_subscription_plan_id
      return if plan_id.blank?
      
      expired_count = 0
      
      # Find all active listings
      BusinessListing.active.includes(:user).find_each(batch_size: 200) do |listing|
        unless listing.user_has_active_subscription?
          listing.update!(is_active: false)
          expired_count += 1
          
          # Optionally send notification to user
          send_expiry_notification(listing.user, listing) if SiteSetting.company_directory_send_expiry_notifications
        end
      end
      
      Rails.logger.info "[CompanyDirectory] Deactivated #{expired_count} expired listings"
      
      # Update site statistics
      if expired_count > 0
        DiscourseEvent.trigger(:company_directory_listings_expired, expired_count)
      end
    end
    
    private
    
    def send_expiry_notification(user, listing)
      # Create a system message to notify the user
      SystemMessage.create_from_system_user(
        user,
        :company_directory_listing_expired,
        {
          business_name: listing.business_name,
          renewal_url: "#{Discourse.base_url}/s"
        }
      )
    rescue => e
      Rails.logger.error "[CompanyDirectory] Failed to send expiry notification to user #{user.id}: #{e.message}"
    end
  end
end
