# frozen_string_literal: true

Bearings::Kramdown::WithLexers = Data.define(:lexers)

# Reopened because rbs-inline reads nothing in a block given to `Data.define` on a compact constant.
class Bearings::Kramdown::WithLexers
  # @rbs source: String
  # @rbs return: Bearings::Document?
  def document(source)
    Bearings::Kramdown.document(source, lexers:)
  end
end
