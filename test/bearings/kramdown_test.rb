# frozen_string_literal: true

require 'test_helper'

describe Bearings::Kramdown do
  def fixture(name)
    File.read(File.join(__dir__, '..', 'fixtures', 'guides', name))
  end

  def document(source)
    Bearings::Kramdown.document(source)
  end

  def sample = document(fixture('sample.md'))

  describe '.document' do
    it 'gives nil for a guide with no "# " title line' do
      assert_nil document("## Install\n\nText\n")
    end

    it 'leaves the title out of the heading ids, so a heading named like it gets the plain id' do
      assert_equal ['overview'], document("# Overview\n\n## Overview\n").headings.map(&:id)
    end

    it 'gives an item in a table the line of its row' do
      assert_equal [6], document("# Title\n\n| a |\n| - |\n| b |\n| [c](c.md) |\n").links.map(&:line)
    end

    it 'gives an item in a footnote definition the line of the definition' do
      assert_equal [5], document("# Title\n\nText[^1]\n\n[^1]: See [x](x.md)\n").links.map(&:line)
    end

    it 'gives an item in a footnote cited from a table row the line of the definition' do
      source = "# Title\n\n| a |\n| - |\n| b[^1] |\n\n[^1]: See [x](x.md)\n"

      assert_equal [7], document(source).links.map(&:line)
    end

    it 'lists an item in a footnote cited twice once' do
      assert_equal 1, document("# Title\n\nA[^1] B[^1]\n\n[^1]: See [x](x.md)\n").links.size
    end

    it 'leaves out an item in a footnote definition nothing cites' do
      assert_empty document("# Title\n\nText\n\n[^1]: See [x](x.md)\n").links
    end

    it 'gives an item in a footnote cited from another footnote the line of its own definition' do
      source = "# Title\n\nText[^n]\n\n[^n]: has [a](a.md) and[^m]\n\n[^m]: inner [b](b.md)\n"

      assert_equal [5, 7], document(source).links.map(&:line)
    end

    it 'lists an item once in footnotes that cite each other' do
      source = "# Title\n\nText[^n]\n\n[^n]: [a](a.md)[^m]\n\n[^m]: [b](b.md)[^n]\n"

      assert_equal %w[a.md b.md], document(source).links.map(&:href)
    end

    it 'leaves out a heading in a footnote definition' do
      assert_empty document("# Title\n\nText[^1]\n\n[^1]: Note\n\n    ## Inner\n").headings
    end

    it 'keeps the line of an item above the title line' do
      assert_equal [1], document("[Home](README.md)\n\n# Title\n").links.map(&:line)
    end

    it 'counts the title line in the line of an item below it' do
      assert_equal [3], document("# Title\n\n[Home](README.md)\n").links.map(&:line)
    end

    it 'takes the title from the "# " line' do
      assert_equal 'Getting started', sample.title
    end

    it 'lists the headings with their level, kramdown id and line' do
      assert_equal(
        [
          Bearings::Document::Heading.new(level: 2, id: 'install', line: 5),
          Bearings::Document::Heading.new(level: 2, id: 'configure-the-manifest--guides', line: 13),
          Bearings::Document::Heading.new(level: 2, id: 'install-1', line: 34)
        ],
        sample.headings
      )
    end

    it 'gives the headings the ids they have in the body' do
      assert_equal sample.body.scan(/<h\d id="([^"]+)"/).flatten, sample.headings.map(&:id)
    end

    it 'lists the links with their href and line' do
      assert_equal(
        [
          Bearings::Document::Link.new(href: 'MANIFEST.md#groups', line: 3),
          Bearings::Document::Link.new(href: 'ORDER.md', line: 17),
          Bearings::Document::Link.new(href: 'https://example.com/docs', line: 36)
        ],
        sample.links
      )
    end

    it 'leaves out indented code blocks' do
      assert_empty document("# Title\n\n    indented\n").code_blocks
    end

    it 'lists the fenced code blocks other than mermaid with their language, code and line' do
      assert_equal(
        [
          Bearings::Document::CodeBlock.new(language: 'ruby', code: "gem 'bearings', '~> 0.1'\n", line: 7),
          Bearings::Document::CodeBlock.new(language: 'json', code: %({ "title": "Docs" }\n), line: 30)
        ],
        sample.code_blocks
      )
    end

    it 'gives a fence with no language a nil language' do
      assert_nil document("# Title\n\n```\nplain\n```\n").code_blocks.first.language
    end

    it 'lists the images with their src, alt text and line' do
      assert_equal [Bearings::Document::Image.new(src: 'images/pipeline.png', alt: 'The build pipeline', line: 23)],
                   sample.images
    end

    it 'lists the mermaid fences as diagrams with their code and line' do
      assert_equal [Bearings::Document::Diagram.new(code: "graph LR\n  guides --> site\n", line: 25)], sample.diagrams
    end

    it "renders the body without the title line, byte for byte as riffer-rig's render_body did" do
      assert_equal fixture('sample.html'), sample.body
    end
  end
end
