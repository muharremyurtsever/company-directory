# Discourse Company Directory Plugin

A comprehensive UK-wide directory of photographers and creative professionals, integrated directly into Discourse with paid subscription support and SEO-optimized pages.

## 🎯 Features

### Core Functionality
- **Subscription-based listings** - Only paying subscribers can create/maintain listings
- **One listing per user** - Each subscriber gets one active business listing
- **City & Category filtering** - Users select from predefined UK cities and photography categories
- **Automatic visibility management** - Listings automatically hide/show based on subscription status

### SEO Features
- **Dynamic SEO pages** - Auto-generated pages for every city+category combination
- **Custom URLs** - Clean URLs like `/directory/london-wedding-photographers`
- **Sitemap integration** - All pages automatically added to sitemap
- **Schema markup** - LocalBusiness structured data for better search results
- **Meta tags** - Unique titles and descriptions for each page

### Business Listings
- **Complete profiles** - Business name, description, contact info, social links
- **Portfolio galleries** - Upload up to 5 images per listing
- **Service packages** - Add pricing and package information
- **Contact methods** - Email, phone, website integration
- **View tracking** - Track profile views and engagement

### Admin Features
- **Admin dashboard** - Manage all listings from one place
- **Bulk actions** - Approve, feature, or delete multiple listings
- **Analytics** - View statistics and popular listings
- **Settings panel** - Configure cities, categories, and limits

## 🚀 Installation

### Prerequisites
- Discourse 3.1.0 or higher
- Discourse Subscriptions plugin enabled
- Stripe account configured

### Step 1: Install Plugin

Add to your `app.yml`:

```yaml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - git clone https://github.com/trbozo/company-directory.git discourse-company-directory
```

Rebuild your container:
```bash
cd /var/discourse
./launcher rebuild app
```

### Step 2: Configure Plugin Settings

Navigate to `Admin → Settings → Plugins → Company Directory`:

| Setting | Description | Default |
|---------|-------------|---------|
| `company_directory_enabled` | Enable the plugin | `false` |
| `company_directory_subscription_plan_id` | Stripe plan ID for listings | `` |
| `company_directory_auto_approve` | Auto-approve new listings | `true` |
| `company_directory_max_images` | Max images per listing | `5` |
| `company_directory_show_in_sitemap` | Include in sitemap | `true` |
| `company_directory_featured_limit` | Max featured per page | `5` |

### Step 3: Configure Locations and Categories

Update the lists in settings:

**Locations** (UK cities):
```
London
Birmingham
Manchester
Liverpool
Leeds
... (see settings.yml for full list)
```

**Categories** (Photography types):
```
Wedding Photographer
Portrait Photographer
Food Photographer
Product Photographer
... (see settings.yml for full list)
```

### Step 4: Set Up Stripe Integration

1. Create subscription products in Stripe:
   - **Name**: "Photography Directory Listing"
   - **Price**: £15-25/month (your choice)
   - **Billing**: Monthly recurring

2. Copy the Price ID from Stripe

3. In Discourse admin:
   - Go to `Admin → Plugins → Subscriptions`
   - Create a new product
   - Enter the Stripe Price ID
   - Set the group to grant access

4. Update plugin setting:
   - Set `company_directory_subscription_plan_id` to your Stripe plan ID

## 📝 Usage

### For Users

1. **Subscribe** - Purchase directory listing subscription
2. **Create listing** - Visit `/my-business` to create your profile
3. **Add content** - Upload images, add packages, set contact info
4. **Manage listing** - Edit anytime while subscription is active

### For Admins

1. **Monitor listings** - Visit `/admin/plugins/company-directory`
2. **Feature listings** - Promote certain businesses
3. **Moderate content** - Approve/reject listings if auto-approve is off
4. **View analytics** - Track popular locations and categories

## 🔍 SEO Implementation

### URL Structure
```
/directory                                    # Main directory
/directory/london-wedding-photographers       # City+category page
/directory/london-wedding-photographers/abc   # Individual business
```

### Generated Pages
The plugin automatically creates SEO pages for every city+category combination with active listings:

- **Unique titles**: "London Wedding Photographers | ThePhotographers.uk"
- **Meta descriptions**: "Find the best wedding photographers in London..."
- **Schema markup**: LocalBusiness structured data
- **Canonical URLs**: Prevent duplicate content
- **Sitemap entries**: All pages indexed automatically

### Background Jobs
- **Daily**: Check subscription status, activate/deactivate listings
- **Weekly**: Generate sitemap entries, update SEO pages

## 🎨 Customization

### Styling
The plugin includes comprehensive SCSS styles in `assets/stylesheets/company-directory.scss`. Key classes:

- `.company-directory-container` - Main wrapper
- `.business-listing-card` - Individual listing cards
- `.business-listing-card.featured` - Featured listings
- `.business-profile` - Individual business pages

### Templates
Customize the HTML templates:

- `app/views/company_directory/index.html.erb` - Directory listing
- `app/views/company_directory/city_category_page.html.erb` - City+category pages
- `app/views/company_directory/business_profile.html.erb` - Individual profiles

### Text & Translations
Modify text in:
- `config/locales/server.en.yml` - Server-side text
- `config/locales/client.en.yml` - Client-side text

## 🔧 API Endpoints

### Public Endpoints
- `GET /directory` - List all businesses
- `GET /directory/:city_category` - City+category page
- `GET /directory/:city_category/:slug` - Business profile

### User Endpoints (Authentication Required)
- `GET /my-business` - Get user's listing
- `POST /my-business` - Create new listing
- `PUT /my-business/:id` - Update listing
- `DELETE /my-business/:id` - Delete listing

### Admin Endpoints (Staff Only)
- `GET /admin/plugins/company-directory` - Admin dashboard
- `GET /admin/plugins/company-directory/listings` - Manage listings
- `PUT /admin/plugins/company-directory/listings/:id` - Update listing
- `DELETE /admin/plugins/company-directory/listings/:id` - Delete listing

## 📊 Database Schema

### BusinessListing Model
```ruby
# Fields
t.string :business_name, null: false
t.text :description, null: false
t.string :city, null: false
t.string :category, null: false
t.string :slug, null: false
t.string :website, :instagram, :facebook, :tiktok
t.string :email, :phone
t.json :images, default: []
t.json :packages, default: []
t.boolean :is_active, default: true
t.boolean :featured, default: false
t.boolean :approved, default: true
t.integer :priority, default: 0
t.integer :views_count, default: 0

# Indexes
add_index :business_listings, :user_id
add_index :business_listings, :slug, unique: true
add_index :business_listings, [:city, :category]
add_index :business_listings, :is_active
add_index :business_listings, :featured
```

## 🚨 Troubleshooting

### Common Issues

**Plugin won't enable**
- Check Discourse version (3.1.0+ required)
- Verify git clone was successful
- Check logs: `/var/discourse/shared/standalone/log/rails/production.log`

**Subscriptions not working**
- Verify Discourse Subscriptions plugin is enabled
- Check Stripe integration is configured
- Verify `company_directory_subscription_plan_id` setting

**SEO pages not generating**
- Check `company_directory_show_in_sitemap` setting
- Run manually: `Rails.application.load_tasks && Rake::Task['company_directory:generate_pages'].invoke`

**Images not uploading**
- Check file upload limits in Discourse settings
- Verify image formats are allowed (jpg, png, gif, webp)
- Check disk space on server

### Debug Commands

```bash
# Check plugin status
cd /var/discourse
./launcher enter app
rails c

# Check if plugin is loaded
Discourse.plugins.map(&:name)

# Check settings
SiteSetting.company_directory_enabled

# Manual job execution
Jobs.enqueue(:deactivate_expired_listings)

# Check database
BusinessListing.count
BusinessListing.active.count
```

## 🔮 Roadmap

### Phase 1 (Current)
- ✅ Basic directory functionality
- ✅ Subscription integration
- ✅ SEO pages
- ✅ Admin dashboard

### Phase 2 (Future)
- 📧 Email notifications for subscriptions
- ⭐ Review and rating system
- 📱 Mobile app API
- 🔍 Advanced search filters
- 📈 Enhanced analytics

### Phase 3 (Planned)
- 🤝 Multi-listing per user (higher tiers)
- 🤖 AI-generated SEO descriptions
- 💬 Direct messaging integration
- 🏆 Featured placement auctions

## 📄 License

This plugin is licensed under the MIT License. See LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📞 Support

For support and questions:
- 📧 Email: support@thephotographers.uk
- 🐛 Issues: [GitHub Issues](https://github.com/trbozo/company-directory/issues)
- 💬 Discussion: [Discourse Meta](https://meta.discourse.org)

---

**Made with ❤️ for the photography community**