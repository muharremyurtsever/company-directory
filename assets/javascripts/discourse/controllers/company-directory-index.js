import Controller from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

export default class CompanyDirectoryIndexController extends Controller {
  @service router;
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
    return this.selectedCity || this.selectedCategory || this.searchQuery;
  }

  @action
  async filterByCity(city) {
    this.selectedCity = city;
    await this.loadListings(true);
  }

  @action
  async filterByCategory(category) {
    this.selectedCategory = category;
    await this.loadListings(true);
  }

  @action
  async search() {
    await this.loadListings(true);
  }

  @action
  async clearFilters() {
    this.selectedCity = null;
    this.selectedCategory = null;
    this.searchQuery = "";
    await this.loadListings(true);
  }

  @action
  async loadMore() {
    if (this.loadingMore || !this.hasMore) return;
    
    this.loadingMore = true;
    this.currentPage += 1;
    
    try {
      await this.loadListings(false);
    } finally {
      this.loadingMore = false;
    }
  }

  @action
  viewProfile(listing) {
    this.router.transitionTo(listing.profile_url);
  }

  async loadListings(reset = false) {
    if (reset) {
      this.currentPage = 1;
      this.loading = true;
    }

    try {
      const params = {
        page: this.currentPage,
        city: this.selectedCity,
        category: this.selectedCategory,
        search: this.searchQuery
      };

      const response = await this.store.query('business-listing', params);
      
      if (reset) {
        this.listings = response.content;
      } else {
        this.listings = [...this.listings, ...response.content];
      }

      this.totalCount = response.pagination.total_count;
      this.hasMore = response.pagination.has_more;

    } catch (error) {
      this.appEvents.trigger("modal-body:flash", {
        text: this.t("generic_error"),
        messageClass: "error"
      });
    } finally {
      this.loading = false;
    }
  }

  t(key, params = {}) {
    return I18n.t(key, params);
  }
}