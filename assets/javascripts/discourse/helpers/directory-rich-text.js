import { htmlSafe } from "@ember/template";
import { helper } from "@ember/component/helper";

function directoryRichText([text], { truncate } = {}) {
  if (!text) return htmlSafe("");

  let processedText = text;

  // Convert newlines to <br>
  processedText = processedText.replace(/\n/g, "<br>");

  // Truncate if specified
  if (truncate && processedText.length > truncate) {
    processedText = processedText.substring(0, truncate) + "...";
  }

  return htmlSafe(processedText);
}

export default helper(directoryRichText);
