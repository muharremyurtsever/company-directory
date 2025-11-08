import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

export default class MyBusinessController extends Controller {
  @service appEvents;
  @service currentUser;
  
  @tracked saving = false;
  @tracked businessName = "";
  @tracked description = "";
  @tracked selectedCity = null;
  @tracked selectedCategory = null;
  @tracked website = "";
  @tracked instagram = "";
  @tracked facebook = "";
  @tracked tiktok = "";
  @tracked email = "";
  @tracked phone = "";
  @tracked uploadedImages = [];
  @tracked packages = [];

  get cities() {
    const allCities = this.model.config.cities || [];
    return allCities.map(city => ({ name: city, value: city }));
  }

  get categories() {
    const allCategories = this.model.config.categories || [];
    return allCategories.map(category => ({ name: category, value: category }));
  }

  get maxImages() {
    return this.model.config.max_images || 5;
  }

  get hasListing() {
    return this.model.has_listing || this.model.listing?.has_listing === true;
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    
    if (model.has_listing && model.listing) {
      // Populate form with existing listing data
      this.populateFormFromListing(model.listing);
    }
  }

  populateFormFromListing(listing) {
    this.businessName = listing.business_name || "";
    this.description = listing.description || "";
    this.selectedCity = listing.city;
    this.selectedCategory = listing.category;
    this.website = listing.website || "";
    this.instagram = listing.instagram || "";
    this.facebook = listing.facebook || "";
    this.tiktok = listing.tiktok || "";
    this.email = listing.email || "";
    this.phone = listing.phone || "";
    this.uploadedImages = listing.image_urls?.map(url => ({ url })) || [];
    this.packages = listing.packages || [];
  }

  @action
  async saveListing(event) {
    event.preventDefault();
    
    if (!this.validateForm()) {
      return;
    }

    this.saving = true;

    try {
      const listingData = {
        business_name: this.businessName,
        description: this.description,
        city: this.selectedCity,
        category: this.selectedCategory,
        website: this.website,
        instagram: this.instagram,
        facebook: this.facebook,
        tiktok: this.tiktok,
        email: this.email,
        phone: this.phone,
        images: this.uploadedImages.map(img => img.url),
        packages: this.packages
      };

      let response;
      if (this.hasListing) {
        response = await this.updateListing(listingData);
      } else {
        response = await this.createListing(listingData);
      }

      if (response.success) {
        this.appEvents.trigger("modal-body:flash", {
          text: response.message,
          messageClass: "success"
        });
      }

    } catch (error) {
      this.appEvents.trigger("modal-body:flash", {
        text: error.message || this.t("generic_error"),
        messageClass: "error"
      });
    } finally {
      this.saving = false;
    }
  }

  @action
  triggerImageUpload() {
    document.getElementById("company-directory-image-upload")?.click();
  }

  @action
  async handleImageUpload(event) {
    const files = Array.from(event.target.files);
    
    if (this.uploadedImages.length + files.length > this.maxImages) {
      this.appEvents.trigger("modal-body:flash", {
        text: this.t("company_directory.validation.too_many_images", { max: this.maxImages }),
        messageClass: "error"
      });
      return;
    }

    for (const file of files) {
      try {
        const uploadResult = await this.uploadImage(file);
        this.uploadedImages = [...this.uploadedImages, { url: uploadResult.url }];
      } catch (error) {
        this.appEvents.trigger("modal-body:flash", {
          text: `Failed to upload ${file.name}: ${error.message}`,
          messageClass: "error"
        });
      }
    }
  }

  @action
  removeImage(index) {
    this.uploadedImages = this.uploadedImages.filter((_, i) => i !== index);
  }

  @action
  addPackage() {
    this.packages = [...this.packages, { name: "", description: "", price: "" }];
  }

  @action
  removePackage(index) {
    this.packages = this.packages.filter((_, i) => i !== index);
  }

  @action
  async deleteListing() {
    if (!confirm(this.t("company_directory.form.confirm_delete"))) {
      return;
    }

    this.saving = true;

    try {
      const response = await fetch(`/my-business/${this.model.listing.id}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      });

      const result = await response.json();

      if (result.success) {
        this.appEvents.trigger("modal-body:flash", {
          text: result.message,
          messageClass: "success"
        });
        
        // Reset form
        this.resetForm();
      }

    } catch (error) {
      this.appEvents.trigger("modal-body:flash", {
        text: error.message || this.t("generic_error"),
        messageClass: "error"
      });
    } finally {
      this.saving = false;
    }
  }

  validateForm() {
    if (!this.businessName.trim()) {
      this.showError("company_directory.validation.business_name_required");
      return false;
    }

    if (!this.description.trim()) {
      this.showError("company_directory.validation.description_required");
      return false;
    }

    if (this.description.length > 500) {
      this.showError("company_directory.validation.description_too_long");
      return false;
    }

    if (!this.selectedCity) {
      this.showError("company_directory.validation.city_required");
      return false;
    }

    if (!this.selectedCategory) {
      this.showError("company_directory.validation.category_required");
      return false;
    }

    // Validate URLs
    const urls = [this.website, this.instagram, this.facebook, this.tiktok].filter(Boolean);
    for (const url of urls) {
      if (!this.isValidUrl(url)) {
        this.showError("company_directory.validation.invalid_url");
        return false;
      }
    }

    // Validate email
    if (this.email && !this.isValidEmail(this.email)) {
      this.showError("company_directory.validation.invalid_email");
      return false;
    }

    return true;
  }

  async createListing(data) {
    const response = await fetch('/my-business', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ business_listing: data })
    });

    return response.json();
  }

  async updateListing(data) {
    const response = await fetch(`/my-business/${this.model.listing.id}`, {
      method: 'PUT',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ business_listing: data })
    });

    return response.json();
  }

  async uploadImage(file) {
    const formData = new FormData();
    formData.append('file', file);
    formData.append('type', 'company_directory');

    const response = await fetch('/uploads.json', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: formData
    });

    if (!response.ok) {
      throw new Error('Upload failed');
    }

    return response.json();
  }

  isValidUrl(string) {
    try {
      new URL(string);
      return true;
    } catch (_) {
      return false;
    }
  }

  isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  showError(key) {
    this.appEvents.trigger("modal-body:flash", {
      text: this.t(key),
      messageClass: "error"
    });
  }

  resetForm() {
    this.businessName = "";
    this.description = "";
    this.selectedCity = null;
    this.selectedCategory = null;
    this.website = "";
    this.instagram = "";
    this.facebook = "";
    this.tiktok = "";
    this.email = "";
    this.phone = "";
    this.uploadedImages = [];
    this.packages = [];
  }

  t(key, params = {}) {
    return I18n.t(key, params);
  }
}
