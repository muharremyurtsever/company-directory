import Route from "@ember/routing/route";

export default class CompanyDirectoryIndexRoute extends Route {

  async model() {
    try {
      const response = await fetch('/directory.json');
      const data = await response.json();
      
      return {
        listings: data.listings || [],
        cities: data.filters?.cities || [],
        categories: data.filters?.categories || [],
        pagination: data.pagination || {}
      };
    } catch (error) {
      console.error('Failed to load directory data:', error);
      return {
        listings: [],
        cities: [],
        categories: [],
        pagination: {}
      };
    }
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.listings = model.listings;
    controller.totalCount = model.pagination.total_count || 0;
    controller.hasMore = model.pagination.has_more || false;
  }
}
