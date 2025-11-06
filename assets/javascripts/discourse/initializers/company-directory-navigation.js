import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "company-directory-navigation",
  
  initialize() {
    withPluginApi("0.8.31", api => {
      // Add directory link to main navigation
      api.decorateWidget("header-icons:before", helper => {
        if (!helper.widget.site.company_directory_enabled) {
          return;
        }

        return helper.h("li", [
          helper.h("a.icon", {
            href: "/directory",
            title: helper.widget.i18n("company_directory.title")
          }, [
            helper.h("svg.fa.d-icon.d-icon-camera", {
              attributes: { "aria-hidden": "true" }
            }),
            " Directory"
          ])
        ]);
      });

      // Add my business link to user menu
      api.decorateWidget("user-menu:before", helper => {
        if (!helper.widget.site.company_directory_enabled) {
          return;
        }

        if (!helper.widget.currentUser?.can_create_business_listing) {
          return;
        }

        return helper.h("li", [
          helper.h("a", {
            href: "/my-business",
            title: helper.widget.i18n("company_directory.my_business")
          }, [
            helper.h("svg.fa.d-icon.d-icon-briefcase", {
              attributes: { "aria-hidden": "true" }
            }),
            " " + helper.widget.i18n("company_directory.my_business")
          ])
        ]);
      });

      // Add directory routes
      api.addDiscoveryQueryParam("directory_city", { replace: true, refreshModel: true });
      api.addDiscoveryQueryParam("directory_category", { replace: true, refreshModel: true });

      // Custom route mappings
      const router = api.container.lookup("router:main");
      router.map(function() {
        this.route("company-directory", { path: "/directory" });
        this.route("my-business", { path: "/my-business" });
      });
    });
  }
};