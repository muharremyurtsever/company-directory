import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("take", take);

export default function take(array, count) {
  if (!array || !Array.isArray(array)) {
    return [];
  }
  return array.slice(0, count);
}
