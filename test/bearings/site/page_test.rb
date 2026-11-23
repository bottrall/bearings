# frozen_string_literal: true

require 'test_helper'

describe Bearings::Site::Page do
  def page(diagrams)
    document = Bearings::Document.new(
      title: 'Start', headings: [], links: [], code_blocks: [], code_spans: [], images: [], diagrams:, body: ''
    )
    Bearings::Site::Page.new(
      title: 'Start',
      slug: 'start',
      description: nil,
      group_label: 'Start here',
      featured: false,
      num: '01',
      url: '/guides/start/',
      markdown_url: '/guides/start.md',
      canonical_url: nil,
      source_path: 'docs/START.md',
      edit_url: nil,
      previous_slug: nil,
      next_slug: nil,
      document:,
      extras: {}
    )
  end

  describe '#diagrams?' do
    it 'is false for a page with no diagrams' do
      refute_predicate page([]), :diagrams?
    end

    it 'is true for a page with a diagram' do
      assert_predicate page([Bearings::Document::Diagram.new(code: "graph TD\n", line: 3)]), :diagrams?
    end
  end
end
