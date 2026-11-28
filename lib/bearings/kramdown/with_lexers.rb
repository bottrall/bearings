# frozen_string_literal: true

class Bearings::Kramdown::WithLexers
  # @rbs @lexers: Bearings::Kramdown::lexers

  # @rbs lexers: Bearings::Kramdown::lexers
  # @rbs return: void
  def initialize(lexers:)
    @lexers = lexers
  end

  # @rbs source: String
  # @rbs return: Bearings::Document?
  def document(source)
    Bearings::Kramdown.document(source, lexers: @lexers)
  end
end
