import { helper } from "@ember/component/helper";

function take([array, count]) {
  if (!array || !Array.isArray(array)) return [];
  return array.slice(0, count);
}

export default helper(take);
