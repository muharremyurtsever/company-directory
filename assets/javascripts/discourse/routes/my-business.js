import Route from "@ember/routing/route";
import { inject as service } from "@ember/service";

export default class MyBusinessRoute extends Route {
  @service currentUser;

  beforeModel() {
    if (!this.currentUser.current) {
      this.transitionTo('login');
    }
  }

  async model() {
    try {
      const response = await fetch('/my-business.json');
      const data = await response.json();
      
      return {
        listing: data.listing,
        has_listing: data.has_listing,
        can_create: data.can_create,
        config: data.config
      };
    } catch (error) {
      console.error('Failed to load business data:', error);
      return {
        listing: null,
        can_create: false,
        config: {
          cities: [],
          categories: [],
          max_images: 5
        }
      };
    }
  }
}
