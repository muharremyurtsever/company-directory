# frozen_string_literal: true

require "securerandom"

class BusinessListing < ActiveRecord::Base
  belongs_to :user
  
  validates :business_name, presence: true, length: { maximum: 100 }
  validates :description, presence: true, length: { maximum: 500 }
  validates :city, presence: true
  validates :category, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :website, :instagram, :facebook, :tiktok, format: { with: URI::DEFAULT_PARSER.make_regexp }, allow_blank: true
  validates :user_id, uniqueness: { scope: :is_active, conditions: -> { where(is_active: true) }, 
                                   message: "can only have one active business listing" }
  
  validate :validate_city_in_allowed_list
  validate :validate_category_in_allowed_list
  validate :validate_images_count
  validate :validate_packages_format
  
  before_validation :generate_slug, on: :create
  before_validation :normalize_urls
  before_validation :normalize_city_and_category
  
  scope :active, -> { where(is_active: true) }
  scope :inactive, -> { where(is_active: false) }
  scope :approved, -> { where(approved: true) }
  scope :pending_approval, -> { where(approved: false) }
  scope :featured, -> { where(featured: true) }
  scope :by_city, ->(city) { where(city: city) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_city_and_category, ->(city, category) { where(city: city, category: category) }
  scope :visible, -> { active.approved }
  scope :for_seo_page, ->(city, category) { visible.by_city_and_category(city, category) }
  scope :ordered_for_display, -> { order(featured: :desc, priority: :desc, created_at: :desc) }
  
  def self.cities_with_listings
    visible.distinct.pluck(:city).sort
  end
  
  def self.categories_with_listings
    visible.distinct.pluck(:category).sort
  end
  
  def self.city_category_combinations
    visible.distinct.pluck(:city, :category).map { |city, category| [city, category] }
  end
  
  def self.search(query)
    return all if query.blank?
    
    where(
      "business_name ILIKE ? OR description ILIKE ? OR city ILIKE ? OR category ILIKE ?",
      "%#{query}%", "%#{query}%", "%#{query}%", "%#{query}%"
    )
  end
  
  def city_category_slug
    "#{city.downcase.gsub(/[^a-z0-9]+/, '-')}-#{category.downcase.gsub(/[^a-z0-9]+/, '-')}"
  end
  
  def profile_url
    "/directory/#{city_category_slug}/#{slug}"
  end
  
  def city_category_page_url
    "/directory/#{city_category_slug}"
  end
  
  def seo_title
    "#{business_name} - #{category} in #{city}"
  end
  
  def seo_description
    description.truncate(160)
  end
  
  def social_links
    links = []
    links << { platform: 'Website', url: website, icon: 'globe' } if website.present?
    links << { platform: 'Instagram', url: instagram, icon: 'fab-instagram' } if instagram.present?
    links << { platform: 'Facebook', url: facebook, icon: 'fab-facebook' } if facebook.present?
    links << { platform: 'TikTok', url: tiktok, icon: 'fab-tiktok' } if tiktok.present?
    links
  end
  
  def contact_methods
    methods = []
    methods << { type: 'email', value: email, label: "Email #{business_name}" } if email.present?
    methods << { type: 'phone', value: phone, label: "Call #{business_name}" } if phone.present?
    methods << { type: 'website', value: website, label: "Visit Website" } if website.present?
    methods
  end
  
  def image_urls
    return [] unless images.is_a?(Array)
    
    images.map do |image_data|
      if image_data.is_a?(Hash) && image_data['url'].present?
        image_data['url']
      elsif image_data.is_a?(String)
        image_data
      end
    end.compact
  end
  
  def formatted_packages
    return [] unless packages.is_a?(Array)
    
    packages.map do |package|
      next unless package.is_a?(Hash)
      
      {
        name: package['name'],
        description: package['description'],
        price: package['price']&.to_f,
        formatted_price: package['price'].present? ? "£#{package['price']}" : nil
      }
    end.compact
  end
  
  def increment_views!
    increment!(:views_count)
  end
  
  def user_has_active_subscription?
    return true unless defined?(DiscourseSubscriptions)
    
    plan_id = SiteSetting.company_directory_subscription_plan_id
    return true if plan_id.blank?
    
    user.can_create_business_listing?
  end
  
  def deactivate_if_subscription_expired!
    unless user_has_active_subscription?
      update!(is_active: false)
    end
  end
  
  def activate_if_subscription_active!
    if user_has_active_subscription? && !is_active?
      update!(is_active: true)
    end
  end
  
  private
  
  def generate_slug
    return if business_name.blank?
    
    base_slug = business_name.downcase
                            .gsub(/[^a-z0-9\s]/, '')
                            .gsub(/\s+/, '-')
                            .strip
                            
    slug_candidate = base_slug
    counter = 1
    
    while BusinessListing.exists?(slug: slug_candidate)
      slug_candidate = counter < 10 ? "#{base_slug}-#{counter}" : "#{base_slug}-#{SecureRandom.hex(2)}"
      counter += 1
    end
    
    self.slug = slug_candidate
  end
  
  def normalize_urls
    [:website, :instagram, :facebook, :tiktok].each do |url_field|
      next if send(url_field).blank?
      
      url = send(url_field)
      unless url.start_with?('http://', 'https://')
        send("#{url_field}=", "https://#{url}")
      end
    end
  end
  
  def normalize_city_and_category
    self.city = city&.titleize
    self.category = category&.titleize
  end
  
  def validate_city_in_allowed_list
    return if city.blank?
    
    allowed_cities = SiteSetting.company_directory_locations.split("\n").map(&:strip)
    unless allowed_cities.include?(city)
      errors.add(:city, "must be selected from the available cities")
    end
  end
  
  def validate_category_in_allowed_list
    return if category.blank?
    
    allowed_categories = SiteSetting.company_directory_categories.split("\n").map(&:strip)
    unless allowed_categories.include?(category)
      errors.add(:category, "must be selected from the available categories")
    end
  end
  
  def validate_images_count
    max_images = SiteSetting.company_directory_max_images
    if images.is_a?(Array) && images.length > max_images
      errors.add(:images, "cannot exceed #{max_images} images")
    end
  end
  
  def validate_packages_format
    return unless packages.is_a?(Array)
    
    packages.each_with_index do |package, index|
      unless package.is_a?(Hash)
        errors.add(:packages, "package #{index + 1} must be a valid format")
        next
      end
      
      if package['name'].blank?
        errors.add(:packages, "package #{index + 1} must have a name")
      end
      
      if package['price'].present? && !package['price'].to_s.match?(/^\d+(\.\d{2})?$/)
        errors.add(:packages, "package #{index + 1} price must be a valid amount")
      end
    end
  end
end
