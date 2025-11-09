import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("1.8.0", (api) => {
  api.addPageRoute("my-business", { path: "/my-business" });
});
