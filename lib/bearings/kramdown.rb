# frozen_string_literal: true

require 'kramdown'

module Bearings::Kramdown
  extend self

  # @rbs!
  #   type located = [::Kramdown::Element, Integer]

  OPTIONS = { input: 'GFM', syntax_highlighter: :rouge, hard_wrap: false }.freeze #: Hash[Symbol, untyped]
  TITLE = /^# .+\n?/ #: Regexp
  ITEM_TYPES = %i[header a img codeblock codespan].freeze #: Array[Symbol]
  HTML_IMAGES = %w[img source].freeze #: Array[String]
  ALERT = /\A\[!(note|tip|important|warning|caution)\][ \t]*\z/i #: Regexp

  # @rbs source: String
  # @rbs return: Bearings::Document?
  def document(source)
    before, heading, after = source.partition(TITLE)
    return if heading.empty?

    parsed = ::Kramdown::Document.new(before + after, OPTIONS)
    notes = footnotes(parsed.root).flat_map { |definition| located(definition) }
    # GFM gives ids only to headings in the main tree, so one in a footnote would have none.
    found = located(parsed.root) + notes.reject { |element, _| element.type == :header }
    elements = in_source(found, before.count("\n") + 1)
    Bearings::Document.new(
      title: heading.delete_prefix('# ').chomp,
      headings: headings(elements),
      links: links(elements),
      code_blocks: code_blocks(elements),
      code_spans: code_spans(elements),
      images: images(elements),
      diagrams: diagrams(elements),
      body: html(parsed)
    )
  end

  private

  # @rbs parsed: ::Kramdown::Document
  # @rbs return: String
  def html(parsed)
    # GitHub renders an alert only at the top level, never nested in another block.
    root = with_children(parsed.root, parsed.root.children.map { |child| alert(child) })
    ::Kramdown::Converter::Html.convert(root, parsed.options).first
  end

  # @rbs element: ::Kramdown::Element
  # @rbs return: ::Kramdown::Element
  def alert(element)
    paragraph, *rest = element.children
    return element unless element.type == :blockquote && paragraph && paragraph.type == :p

    text, *spans = paragraph.children
    return element unless text && text.type == :text

    first_line, newline, remainder = text.value.partition("\n")
    kind = first_line[ALERT, 1]
    whole_line = newline == "\n" || spans.empty?
    return element unless kind && whole_line

    lead = [::Kramdown::Element.new(:text, remainder, nil, text.options), *spans]
    body = remainder.empty? && spans.empty? ? rest : [with_children(paragraph, lead), *rest]
    div = ::Kramdown::Element.new(
      :html_element, 'div', { 'class' => "alert alert-#{kind.downcase}" }, { category: :block, content_model: :block }
    )
    with_children(div, [title(kind.capitalize), *body])
  end

  # @rbs label: String
  # @rbs return: ::Kramdown::Element
  def title(label)
    paragraph = ::Kramdown::Element.new(:p, nil, { 'class' => 'alert-title' })
    with_children(paragraph, [::Kramdown::Element.new(:text, label)])
  end

  # @rbs element: ::Kramdown::Element
  # @rbs children: Array[::Kramdown::Element]
  # @rbs return: ::Kramdown::Element
  def with_children(element, children)
    element.dup.tap { |copy| copy.children = children }
  end

  # @rbs element: ::Kramdown::Element
  # @rbs return: Array[located]
  def located(element)
    inside = element.type == :table ? table_rows(element) : element.children.flat_map { |child| located(child) }
    item?(element) ? [[element, element.options[:location]], *inside] : inside
  end

  # @rbs element: ::Kramdown::Element
  # @rbs return: bool
  def item?(element)
    ITEM_TYPES.include?(element.type) || (element.type == :html_element && HTML_IMAGES.include?(element.value))
  end

  # @rbs element: ::Kramdown::Element
  # @rbs seen: Array[::Kramdown::Element]
  # @rbs return: Array[::Kramdown::Element]
  def footnotes(element, seen = [])
    element.children.reduce(seen) do |found, child|
      next footnotes(child, found) unless child.type == :footnote
      next found if found.include?(child.value)

      footnotes(child.value, [*found, child.value])
    end
  end

  # @rbs table: ::Kramdown::Element
  # @rbs return: Array[located]
  def table_rows(table)
    # a separator line comes before each section after the first
    lines = table.children.flat_map { |section| [nil, *section.children] }.drop(1)
    lines.each_with_index.flat_map do |row, offset|
      # kramdown parses each cell on its own, so cells report line 1
      row ? located(row).map { |element, _| [element, table.options[:location] + offset] } : []
    end
  end

  # @rbs elements: Array[located]
  # @rbs title_line: Integer
  # @rbs return: Array[located]
  def in_source(elements, title_line)
    elements.map { |element, line| [element, line < title_line ? line : line + 1] }
  end

  # @rbs elements: Array[located]
  # @rbs return: Array[Bearings::Document::Heading]
  def headings(elements)
    elements.filter_map do |element, line|
      if element.type == :header
        Bearings::Document::Heading.new(level: element.options[:level], id: element.attr['id'], line:)
      end
    end
  end

  # @rbs elements: Array[located]
  # @rbs return: Array[Bearings::Document::Link]
  def links(elements)
    elements.filter_map do |element, line|
      Bearings::Document::Link.new(href: element.attr['href'], line:) if element.type == :a
    end
  end

  # @rbs elements: Array[located]
  # @rbs return: Array[Bearings::Document::CodeBlock]
  def code_blocks(elements)
    elements.filter_map do |element, line|
      next unless fence?(element) && !diagram?(element)

      Bearings::Document::CodeBlock.new(language: element.options[:lang], code: element.value, line:)
    end
  end

  # @rbs elements: Array[located]
  # @rbs return: Array[Bearings::Document::CodeSpan]
  def code_spans(elements)
    elements.filter_map do |element, line|
      Bearings::Document::CodeSpan.new(code: element.value, line:) if element.type == :codespan
    end
  end

  # @rbs elements: Array[located]
  # @rbs return: Array[Bearings::Document::Image]
  def images(elements)
    elements.flat_map do |element, line|
      case element.type
      when :img then [Bearings::Document::Image.new(src: element.attr['src'], alt: element.attr['alt'], line:)]
      when :html_element then html_images(element, line)
      else []
      end
    end
  end

  # @rbs element: ::Kramdown::Element
  # @rbs line: Integer
  # @rbs return: Array[Bearings::Document::Image]
  def html_images(element, line)
    # A <source> takes no alt text: the <img> in its <picture> describes it.
    alt = element.attr['alt'].to_s if element.value == 'img'
    urls = element.attr.values_at('src', 'srcset').compact.flat_map do |value|
      value.scan(Bearings::Images::SOURCE_URL) #: Array[String]
    end
    urls.map { |src| Bearings::Document::Image.new(src:, alt:, line:) }
  end

  # @rbs elements: Array[located]
  # @rbs return: Array[Bearings::Document::Diagram]
  def diagrams(elements)
    elements.filter_map do |element, line|
      Bearings::Document::Diagram.new(code: element.value, line:) if fence?(element) && diagram?(element)
    end
  end

  # @rbs element: ::Kramdown::Element
  # @rbs return: bool
  def fence?(element)
    element.type == :codeblock && element.options[:fenced] == true
  end

  # @rbs element: ::Kramdown::Element
  # @rbs return: bool
  def diagram?(element)
    element.options[:lang] == 'mermaid'
  end
end
