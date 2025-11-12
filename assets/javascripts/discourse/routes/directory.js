import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import { action } from "@ember/object";

export default class DirectoryRoute extends DiscourseRoute {
  queryParams = {
    city: { refreshModel: true },
    category: { refreshModel: true },
    search: { refreshModel: true },
    page: { refreshModel: true },
  };

  model(params) {
    const queryParams = {};
    if (params.city) queryParams.city = params.city;
    if (params.category) queryParams.category = params.category;
    if (params.search) queryParams.search = params.search;
    if (params.page) queryParams.page = params.page;

    return ajax("/directory.json", { data: queryParams }).then((data) => {
      // Process listings to format descriptions with line breaks
      const processedListings = (data.listings || []).map((listing) => {
        if (listing.description) {
          // Convert newlines to <br> tags and truncate
          let processed = listing.description.replace(/\n/g, "<br>");
          if (processed.length > 200) {
            processed = processed.substring(0, 200) + "...";
          }
          // Return plain string - template will handle HTML rendering with {{{ }}}
          listing.formattedDescription = processed;
        } else {
          listing.formattedDescription = "";
        }
        return listing;
      });

      return {
        listings: processedListings,
        pagination: data.pagination || {},
        filters: data.filters || { cities: [], categories: [] },
      };
    });
  }

  setupController(controller, model) {
    super.setupController(controller, model);
    controller.set("listings", model.listings);
    controller.set("pagination", model.pagination);
    controller.set("cities", model.filters.cities);
    controller.set("categories", model.filters.categories);
  }

  @action
  error(error) {
    if (error.jqXHR?.status === 404) {
      this.replaceWith("/404");
    }
    return true;
  }

  titleToken() {
    return "UK Photography Directory";
  }
}
