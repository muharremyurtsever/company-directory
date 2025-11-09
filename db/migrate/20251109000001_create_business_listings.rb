# frozen_string_literal: true

class CreateBusinessListings < ActiveRecord::Migration[7.0]
  def change
    return if table_exists?(:business_listings)

    create_table :business_listings do |t|
      t.references :user, null: false, foreign_key: true
      t.string :business_name, null: false
      t.text :description, null: false
      t.string :city, null: false
      t.string :category, null: false
      t.string :slug, null: false
      t.string :website
      t.string :instagram
      t.string :facebook
      t.string :tiktok
      t.string :email
      t.string :phone
      t.json :images, default: []
      t.json :packages, default: []
      t.boolean :is_active, default: true
      t.boolean :featured, default: false
      t.boolean :approved, default: true
      t.integer :priority, default: 0
      t.integer :views_count, default: 0
      t.timestamps
    end

    add_index :business_listings, :user_id, name: "idx_bl_user" unless index_exists?(:business_listings, :user_id, name: "idx_bl_user")
    add_index :business_listings, :slug, unique: true, name: "idx_bl_slug" unless index_exists?(:business_listings, :slug, name: "idx_bl_slug")
    add_index :business_listings, [:city, :category], name: "idx_bl_city_cat" unless index_exists?(:business_listings, [:city, :category], name: "idx_bl_city_cat")
    add_index :business_listings, :is_active, name: "idx_bl_active" unless index_exists?(:business_listings, :is_active, name: "idx_bl_active")
    add_index :business_listings, :featured, name: "idx_bl_featured" unless index_exists?(:business_listings, :featured, name: "idx_bl_featured")
    add_index :business_listings, :approved, name: "idx_bl_approved" unless index_exists?(:business_listings, :approved, name: "idx_bl_approved")
    add_index :business_listings, [:city, :category, :is_active, :approved], name: "idx_bl_search" unless index_exists?(:business_listings, [:city, :category, :is_active, :approved], name: "idx_bl_search")
    add_index :business_listings, [:featured, :priority, :created_at], name: "idx_bl_priority" unless index_exists?(:business_listings, [:featured, :priority, :created_at], name: "idx_bl_priority")
  end
end