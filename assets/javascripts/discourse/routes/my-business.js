import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import { inject as service } from "@ember/service";

export default class MyBusinessRoute extends DiscourseRoute {
  @service router;
  @service siteSettings;

  beforeModel() {
    if (!this.currentUser) {
      return this.router.transitionTo("login");
    }
  }

  model() {
    return ajax("/my-business.json");
  }

  setupController(controller, model) {
    controller.setProperties({
      canCreate: model.can_create,
      hasListing: model.has_listing,
      listing: model.listing,
      cities: model.config?.cities || [],
      categories: model.config?.categories || [],
      maxImages: model.config?.max_images || this.siteSettings.company_directory_max_images,
    });

    controller.resetForm();
  }

  titleToken() {
    return I18n.t("company_directory.my_business");
  }
}
