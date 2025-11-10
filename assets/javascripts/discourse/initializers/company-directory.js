import { apiInitializer } from "discourse/lib/api";
import { withPluginApi } from "discourse/lib/plugin-api";

export default apiInitializer("1.8.0", (api) => {
  withPluginApi("1.8.0", (api) => {
    // Register custom route with Discourse router
    api.addRoute("my-business", {
      path: "/my-business",
      controller: "my-business",
      route: "my-business",
    });
  });
});
