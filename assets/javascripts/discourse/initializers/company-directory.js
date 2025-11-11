import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", (api) => {
  // Custom routes are registered in plugin.rb and automatically discovered by Discourse
  // No explicit route registration needed here
});
