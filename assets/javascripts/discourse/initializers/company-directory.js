import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", (api) => {
  // Route is handled server-side in plugin.rb - no client-side route needed
  // Server-side rendering with crawler layout for SEO
});
