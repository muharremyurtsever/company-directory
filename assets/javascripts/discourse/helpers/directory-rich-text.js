import { htmlSafe } from "@ember/template";
import { registerRawHelper } from "discourse-common/lib/helpers";

registerRawHelper("directory-rich-text", directoryRichText);

export default function directoryRichText(text, params) {
  if (!text) {
    return "";
  }

  const truncateAt = params?.hash?.truncate;
  let processedText = text;

  // Basic sanitization - convert newlines to <br> tags
  processedText = processedText.replace(/\n/g, "<br>");

  // Truncate if specified
  if (truncateAt && processedText.length > truncateAt) {
    processedText = processedText.substring(0, truncateAt) + "...";
  }

  return htmlSafe(processedText);
}
