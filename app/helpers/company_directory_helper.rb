# frozen_string_literal: true

module CompanyDirectoryHelper
  def directory_rich_text(text, truncate_at: nil)
    return "".html_safe if text.blank?

    content = text.to_s
    content = truncate(content, length: truncate_at, separator: " ") if truncate_at
    sanitize(simple_format(content))
  end
end
