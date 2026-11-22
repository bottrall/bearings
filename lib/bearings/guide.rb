# frozen_string_literal: true

module Bearings::Guide
  extend self

  # @rbs file: String
  # @rbs source: String
  # @rbs markdown: Bearings::_Markdown
  # @rbs return: Bearings::Document | Bearings::Problem
  def parse(file, source, markdown)
    markdown.document(source) || untitled(file)
  end

  private

  # @rbs file: String
  # @rbs return: Bearings::Problem
  def untitled(file)
    Bearings::Problem.new(
      check: 'title',
      level: :error,
      file:,
      line: 1,
      message: 'has no "# " title line',
      hint: 'start the guide with a "# Title" line; it becomes the page title'
    )
  end
end
