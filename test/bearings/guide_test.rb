# frozen_string_literal: true

require 'test_helper'

describe Bearings::Guide do
  def titled
    Bearings::Document.new(
      title: 'Title',
      headings: [],
      links: [],
      code_blocks: [],
      code_spans: [],
      images: [],
      diagrams: [],
      body: ''
    )
  end

  def markdown
    Struct.new(:documents) { def document(source) = documents[source] }.new({ "# Title\n" => titled })
  end

  describe '.parse' do
    it 'reports a guide the markdown finds no title in' do
      assert_equal(
        Bearings::Problem.new(
          check: 'title',
          level: :error,
          file: 'guides/start.md',
          line: 1,
          message: 'has no "# " title line',
          hint: 'start the guide with a "# Title" line; it becomes the page title'
        ),
        Bearings::Guide.parse('guides/start.md', "Text\n", markdown)
      )
    end

    it 'gives the document the markdown parses from the source' do
      assert_equal titled, Bearings::Guide.parse('guides/start.md', "# Title\n", markdown)
    end
  end
end
