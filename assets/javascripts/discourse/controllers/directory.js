import Controller from "@ember/controller";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class DirectoryController extends Controller {
  queryParams = ["city", "category", "search", "page"];

  @tracked city = null;
  @tracked category = null;
  @tracked search = null;
  @tracked page = 1;
  @tracked listings = [];
  @tracked pagination = {};
  @tracked cities = [];
  @tracked categories = [];

  get selectedCity() {
    return this.city || "";
  }

  get selectedCategory() {
    return this.category || "";
  }

  get searchQuery() {
    return this.search || "";
  }

  get totalCount() {
    return this.pagination.total_count || 0;
  }

  get currentPage() {
    return this.pagination.current_page || 1;
  }

  get totalPages() {
    return this.pagination.total_pages || 1;
  }

  get hasMore() {
    return this.pagination.has_more || false;
  }

  get featuredListings() {
    return this.listings.filter((listing) => listing.featured).slice(0, 5);
  }

  get regularListings() {
    return this.listings.filter((listing) => !listing.featured);
  }

  get hasAnyFilters() {
    return !!this.city || !!this.category || !!this.search;
  }

  get cityOptions() {
    return [
      { value: "", name: "All Cities" },
      ...this.cities.map((city) => ({ value: city, name: city })),
    ];
  }

  get categoryOptions() {
    return [
      { value: "", name: "All Categories" },
      ...this.categories.map((category) => ({
        value: category,
        name: category,
      })),
    ];
  }

  get canShowManageListing() {
    return this.currentUser?.can_create_business_listing;
  }

  @action
  applyFilters() {
    // Reset to page 1 when applying new filters
    this.page = 1;
  }

  @action
  clearFilters() {
    this.city = null;
    this.category = null;
    this.search = null;
    this.page = 1;
  }

  @action
  previousPage() {
    if (this.currentPage > 1) {
      this.page = this.currentPage - 1;
    }
  }

  @action
  nextPage() {
    if (this.currentPage < this.totalPages) {
      this.page = this.currentPage + 1;
    }
  }
}
