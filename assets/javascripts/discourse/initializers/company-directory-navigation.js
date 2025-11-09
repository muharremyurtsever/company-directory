import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "company-directory-navigation",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    // Only initialize if plugin is enabled
    if (!siteSettings.company_directory_enabled) {
      return;
    }

    withPluginApi("0.8.31", api => {
      // Add directory link to main navigation
      api.decorateWidget("header-icons:before", helper => {
        const settings = helper.widget.siteSettings;
        if (!settings || !settings.company_directory_enabled) {
          return;
        }

        return helper.h("li", [
          helper.h("a.icon", {
            href: "/directory",
            title: "Company Directory"
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
        const settings = helper.widget.siteSettings;
        if (!settings || !settings.company_directory_enabled) {
          return;
        }

        if (!helper.widget.currentUser?.can_create_business_listing) {
          return;
        }

        return helper.h("li", [
          helper.h("a", {
            href: "/my-business",
            title: "My Business"
          }, [
            helper.h("svg.fa.d-icon.d-icon-briefcase", {
              attributes: { "aria-hidden": "true" }
            }),
            " My Business"
          ])
        ]);
      });
    });
  }
};