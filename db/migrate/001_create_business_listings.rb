# frozen_string_literal: true

class CreateBusinessListings < ActiveRecord::Migration[7.0]
  def change
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

    add_index :business_listings, :user_id
    add_index :business_listings, :slug, unique: true
    add_index :business_listings, [:city, :category]
    add_index :business_listings, :is_active
    add_index :business_listings, :featured
    add_index :business_listings, :approved
    add_index :business_listings, [:city, :category, :is_active, :approved]
    add_index :business_listings, [:featured, :priority, :created_at]
  end
end