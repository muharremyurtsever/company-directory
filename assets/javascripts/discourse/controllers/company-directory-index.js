import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

export default class CompanyDirectoryIndexController extends Controller {
  @service appEvents;
  
  @tracked listings = [];
  @tracked loading = false;
  @tracked loadingMore = false;
  @tracked selectedCity = null;
  @tracked selectedCategory = null;
  @tracked searchQuery = "";
  @tracked currentPage = 1;
  @tracked totalCount = 0;
  @tracked hasMore = false;

  get cities() {
    const allCities = this.model.cities || [];
    return [
      { name: this.t("company_directory.directory.all_cities"), value: null },
      ...allCities.map(city => ({ name: city, value: city }))
    ];
  }

  get categories() {
    const allCategories = this.model.categories || [];
    return [
      { name: this.t("company_directory.directory.all_categories"), value: null },
      ...allCategories.map(category => ({ name: category, value: category }))
    ];
  }

  get hasFilters() {
    return Boolean(this.selectedCity || this.selectedCategory || this.searchQuery);
  }

  @action
  async filterByCity(city) {
    this.selectedCity = city;
    await this.loadListings({ reset: true });
  }

  @action
  async filterByCategory(category) {
    this.selectedCategory = category;
    await this.loadListings({ reset: true });
  }

  @action
  async search() {
    await this.loadListings({ reset: true });
  }

  @action
  async clearFilters() {
    this.selectedCity = null;
    this.selectedCategory = null;
    this.searchQuery = "";
    await this.loadListings({ reset: true });
  }

  @action
  async loadMore() {
    if (this.loadingMore || !this.hasMore) return;
    
    this.loadingMore = true;
    try {
      await this.loadListings({ page: this.currentPage + 1 });
    } finally {
      this.loadingMore = false;
    }
  }

  @action
  viewProfile(listing) {
    if (listing?.profile_url) {
      window.location.assign(listing.profile_url);
    }
  }

  async loadListings({ reset = false, page = null } = {}) {
    const previousPage = this.currentPage;
    const targetPage = reset ? 1 : page || this.currentPage;

    if (reset) {
      this.currentPage = 1;
      this.loading = true;
    }

    try {
      const params = {
        page: targetPage,
        city: this.selectedCity,
        category: this.selectedCategory,
        search: this.searchQuery
      };

      const data = await this.fetchListings(params);
      const newListings = data.listings || [];
      const pagination = data.pagination || {};

      if (reset) {
        this.listings = newListings;
      } else {
        this.listings = [...this.listings, ...newListings];
      }
      
      this.totalCount = pagination.total_count || 0;
      this.hasMore = Boolean(pagination.has_more);
      this.currentPage = targetPage;
    } catch (error) {
      this.appEvents.trigger("modal-body:flash", {
        text: error.message || this.t("generic_error"),
        messageClass: "error"
      });
      if (!reset) {
        this.currentPage = previousPage;
      }
    } finally {
      if (reset) {
        this.loading = false;
      }
    }
  }

  async fetchListings(params) {
    const searchParams = new URLSearchParams();

    Object.entries(params).forEach(([key, value]) => {
      if (value) {
        searchParams.append(key, value);
      }
    });

    const queryString = searchParams.toString();
    const response = await fetch(`/directory.json${queryString ? `?${queryString}` : ""}`);

    if (!response.ok) {
      throw new Error("Unable to load directory listings");
    }

    return response.json();
  }

  t(key, params = {}) {
    return I18n.t(key, params);
  }
}
