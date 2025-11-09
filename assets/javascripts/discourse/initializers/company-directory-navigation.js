import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "company-directory-navigation",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    // Only initialize if plugin is enabled
    if (!siteSettings.company_directory_enabled) {
      return;
    }

    withPluginApi("1.8.0", api => {
      // Add directory icon to header using modern API
      api.headerIcons.add("directory", {
        href: "/directory",
        title: "Company Directory",
        icon: "camera",
        text: "Directory"
      });

      // Add my business link to user menu using modern API
      api.addQuickAccessProfileItem({
        icon: "briefcase",
        href: "/my-business",
        content: "My Business",
        condition() {
          return api.getCurrentUser()?.can_create_business_listing;
        }
      });
    });
  }
};