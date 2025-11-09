import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";

export default class MyBusinessController extends Controller {
  @service siteSettings;
  @tracked canCreate = false;
  @tracked hasListing = false;
  @tracked listing = null;
  @tracked cities = [];
  @tracked categories = [];
  @tracked maxImages = 0;
  @tracked form = this.buildEmptyForm();
  @tracked errors = null;
  @tracked successMessage = null;
  @tracked saving = false;
  @tracked deleting = false;
  @tracked uploading = false;

  resetForm() {
    this.form = this.buildFormFromListing(this.listing);
    this.errors = null;
    this.successMessage = null;
  }

  buildEmptyForm() {
    return {
      id: null,
      business_name: "",
      description: "",
      city: "",
      category: "",
      website: "",
      instagram: "",
      facebook: "",
      tiktok: "",
      email: "",
      phone: "",
      packages: [],
      images: [],
    };
  }

  buildFormFromListing(listing) {
    if (!listing) {
      return this.buildEmptyForm();
    }

    return {
      id: listing.id,
      business_name: listing.business_name || "",
      description: listing.description || "",
      city: listing.city || "",
      category: listing.category || "",
      website: listing.website || "",
      instagram: listing.instagram || "",
      facebook: listing.facebook || "",
      tiktok: listing.tiktok || "",
      email: listing.email || "",
      phone: listing.phone || "",
      packages: (listing.packages || []).map((pkg, index) => ({
        name: pkg.name || "",
        description: pkg.description || "",
        price: pkg.price ? pkg.price.toString() : "",
        key: `${listing.id || "pkg"}-${index}`,
      })),
      images: (listing.images || []).map((image) => ({
        upload_id: image.upload_id || image["upload_id"],
        url: image.url,
        name: image.original_filename,
      })),
    };
  }

  get hasImages() {
    return this.form.images.length > 0;
  }

  get remainingImageSlots() {
    return Math.max(this.maxImages - this.form.images.length, 0);
  }

  get canAddMoreImages() {
    return this.form.images.length < this.maxImages;
  }

  serializeFormPayload() {
    return {
      business_name: this.form.business_name,
      description: this.form.description,
      city: this.form.city,
      category: this.form.category,
      website: this.form.website,
      instagram: this.form.instagram,
      facebook: this.form.facebook,
      tiktok: this.form.tiktok,
      email: this.form.email,
      phone: this.form.phone,
      packages: this.form.packages
        .filter((pkg) => (pkg.name || "").trim().length)
        .map((pkg) => ({
          name: pkg.name,
          description: pkg.description,
          price: pkg.price,
        })),
      images: this.form.images.map((image) => ({ upload_id: image.upload_id })),
    };
  }

  @action
  updateField(field, event) {
    const value = event?.target ? event.target.value : event;
    this.form = { ...this.form, [field]: value };
  }

  @action
  updatePackageField(index, field, event) {
    const value = event?.target ? event.target.value : event;
    const packages = this.form.packages.slice();
    packages[index] = { ...packages[index], [field]: value };
    this.form = { ...this.form, packages };
  }

  @action
  addPackage() {
    const packages = this.form.packages.slice();
    packages.push({ name: "", description: "", price: "", key: `pkg-${packages.length}` });
    this.form = { ...this.form, packages };
  }

  @action
  removePackage(index) {
    const packages = this.form.packages.slice();
    packages.splice(index, 1);
    this.form = { ...this.form, packages };
  }

  @action
  removeImage(image) {
    const images = this.form.images.filter((img) => img.upload_id !== image.upload_id);
    this.form = { ...this.form, images };
  }

  @action
  async handleFileSelection(event) {
    const files = event.target.files;
    if (!files || files.length === 0) {
      return;
    }

    await this.uploadSelectedFiles(files);
    event.target.value = null;
  }

  async uploadSelectedFiles(fileList) {
    if (!fileList?.length) {
      return;
    }

    const files = Array.from(fileList);

    for (const file of files) {
      if (!this.canAddMoreImages) {
        break;
      }

      const formData = new FormData();
      formData.append("file", file);

      try {
        this.uploading = true;
        const response = await ajax("/company-directory/uploads", {
          method: "POST",
          data: formData,
          processData: false,
          contentType: false,
        });

        (response.uploads || []).forEach((upload) => {
          if (this.form.images.length < this.maxImages) {
            const images = this.form.images.concat({
              upload_id: upload.id,
              url: upload.url,
              name: upload.original_filename,
            });
            this.form = { ...this.form, images };
          }
        });
      } catch (error) {
        popupAjaxError(error);
        break;
      } finally {
        this.uploading = false;
      }
    }
  }

  @action
  async saveListing(event) {
    event?.preventDefault();

    if (!this.canCreate) {
      return;
    }

    this.saving = true;
    this.errors = null;
    this.successMessage = null;

    const path = this.form.id ? `/my-business/${this.form.id}.json` : "/my-business.json";
    const method = this.form.id ? "PUT" : "POST";

    try {
      const response = await ajax(path, {
        method,
        data: { business_listing: this.serializeFormPayload() },
      });

      if (response?.success) {
        this.hasListing = true;
        this.listing = response.listing;
        this.form = this.buildFormFromListing(response.listing);
        this.successMessage = response.message;
      }
    } catch (error) {
      if (error?.jqXHR?.responseJSON?.errors) {
        this.errors = error.jqXHR.responseJSON.errors;
      } else if (error?.responseJSON?.errors) {
        this.errors = error.responseJSON.errors;
      } else {
        popupAjaxError(error);
      }
    } finally {
      this.saving = false;
    }
  }

  @action
  async deleteListing() {
    if (!this.form.id) {
      return;
    }

    if (!confirm(I18n.t("company_directory.form.confirm_delete"))) {
      return;
    }

    this.deleting = true;

    try {
      await ajax(`/my-business/${this.form.id}.json`, { method: "DELETE" });
      this.hasListing = false;
      this.listing = null;
      this.resetForm();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.deleting = false;
    }
  }
}
