# frozen_string_literal: true

require 'pathname'

module Bearings::MarkdownCopies
  extend self

  # @rbs!
  #   type rewrite = [String, Integer, String]

  SCHEME = /\A[a-z][a-z\d+.-]*:/i #: Regexp
  # A code span or an escaped bracket comes first so a link-shaped string inside one is matched, and kept, as written.
  INLINE = /(?<code>(?<!`)(?<ticks>`+)(?!`).*?(?<!`)\k<ticks>(?!`))|(?<escaped>\\\[[^\]\n]*\]\()|(?<lead>\]\([ \t]*<?)(?<destination>[^\s<>()]+)/ #: Regexp
  DEFINITION = /\A(?<lead> {0,3}\[(?!\^)[^\]\n]+\]:[ \t]*<?)(?<destination>[^\s<>]+)/ #: Regexp

  # @rbs site: Bearings::Site
  # @rbs files: Hash[String, String]
  # @rbs return: Array[Bearings::OutputFile]
  def call(site, files)
    copies = site.pages.to_h { |page| [page.source_path, page.markdown_url] }
    assets = "#{site.details.url&.delete_suffix('/')}/assets/"
    site.pages.map do |page|
      Bearings::OutputFile.new(
        path: page.markdown_url.delete_prefix('/'),
        content: copy(files.fetch(page.source_path), page.document, rewrites(page, copies, assets))
      )
    end
  end

  private

  # @rbs page: Bearings::Site::Page
  # @rbs copies: Hash[String, String]
  # @rbs assets: String
  # @rbs return: Array[rewrite]
  def rewrites(page, copies, assets)
    folder = File.dirname(page.source_path)
    links = page.document.links.filter_map do |link|
      path, hash, fragment = link.href.partition('#')
      url = copies[in_repo(folder, path)] if relative?(link.href)
      [link.href, link.line, "#{url}#{hash}#{fragment}"] if url
    end #: Array[rewrite]
    images = page.document.images.filter_map do |image|
      [image.src, image.line, "#{assets}#{in_repo(folder, image.src)}"] if relative?(image.src)
    end #: Array[rewrite]
    links + images
  end

  # @rbs destination: String
  # @rbs return: bool
  def relative?(destination)
    !destination.match?(SCHEME) && !destination.start_with?('/')
  end

  # @rbs folder: String
  # @rbs path: String
  # @rbs return: String
  def in_repo(folder, path)
    Pathname.new(File.join(folder, path)).cleanpath.to_s
  end

  # @rbs source: String
  # @rbs document: Bearings::Document
  # @rbs rewrites: Array[rewrite]
  # @rbs return: String
  def copy(source, document, rewrites)
    lines = source.lines
    breaks = breaks(lines, document)
    unused = rewrites
    lines.map.with_index(1) do |line, number|
      next line if breaks.include?(number)

      copied, unused = inline(definition(line, rewrites), number, unused, breaks)
      copied
    end.join
  end

  # @rbs lines: Array[String]
  # @rbs document: Bearings::Document
  # @rbs return: Set[Integer]
  def breaks(lines, document)
    fenced = [*document.code_blocks, *document.diagrams].flat_map do |block|
      (block.line..(block.line + block.code.lines.count + 1)).to_a
    end
    blank = lines.filter_map.with_index(1) { |line, number| number if line.strip.empty? }
    Set.new(fenced + blank)
  end

  # @rbs from: Integer
  # @rbs to: Integer
  # @rbs breaks: Set[Integer]
  # @rbs return: bool
  def same_paragraph?(from, to, breaks)
    from <= to && breaks.disjoint?(from..to)
  end

  # @rbs line: String
  # @rbs rewrites: Array[rewrite]
  # @rbs return: String
  def definition(line, rewrites)
    line.sub(DEFINITION) do
      match = Regexp.last_match #: MatchData
      url = rewrites.find { |destination, _, _| destination == match[:destination] }&.last
      url ? "#{match[:lead]}#{url}" : match.to_s
    end
  end

  # @rbs line: String
  # @rbs number: Integer
  # @rbs unused: Array[rewrite]
  # @rbs breaks: Set[Integer]
  # @rbs return: [String, Array[rewrite]]
  def inline(line, number, unused, breaks)
    left = unused
    rewritten = line.gsub(INLINE) do
      match = Regexp.last_match #: MatchData
      # Each link kramdown found in this paragraph rewrites one destination; a copy in plain text stays as written.
      found = left.index do |destination, at, _|
        destination == match[:destination] && same_paragraph?(at, number, breaks)
      end
      next match.to_s unless found

      url = left.fetch(found).last
      left = left.reject.with_index { |_, index| index == found }
      "#{match[:lead]}#{url}"
    end
    [rewritten, left]
  end
end
