# frozen_string_literal: true

Bearings::Site::Page = Data.define(
  :title,
  :slug,
  :description,
  :group_label,
  :featured,
  :num,
  :url,
  :markdown_url,
  :canonical_url,
  :source_path,
  :edit_url,
  :previous_slug,
  :next_slug,
  :document,
  :extras
)

# Reopened because rbs-inline reads nothing in a block given to `Data.define` on a compact constant.
class Bearings::Site::Page
  # @rbs return: bool
  def diagrams?
    document.diagrams.any?
  end
end
