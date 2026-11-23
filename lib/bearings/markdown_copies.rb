# frozen_string_literal: true

module Bearings::MarkdownCopies
  extend self

  # @rbs!
  #   type rewrite = [String, Integer, String]

  CODE_SPAN = /(?<!`)(?<ticks>`+)(?!`).*?(?<!`)\k<ticks>(?!`)/ #: Regexp
  # A code span or an escaped bracket comes first so a link-shaped string inside one is matched, and kept, as written.
  INLINE = /(?<code>#{CODE_SPAN})|(?<escaped>\\\[[^\]\n]*\]\()|(?<lead>\]\([ \t]*<?)(?<destination>[^\s<>()]+)|(?<attribute>\s(?<source>#{Bearings::Images::SOURCE_URLS.keys.join('|')})=["'])(?<value>[^"'\n]*)/ #: Regexp
  DEFINITION = /\A(?<lead> {0,3}\[(?!\^)[^\]\n]+\]:[ \t]*<?)(?<destination>[^\s<>]+)/ #: Regexp

  # @rbs site: Bearings::Site
  # @rbs files: Hash[String, String]
  # @rbs return: Array[Bearings::OutputFile]
  def call(site, files)
    copies = site.pages.to_h { |page| [page.source_path, page.markdown_url] }
    site_url = site.details.url&.delete_suffix('/')
    site.pages.map do |page|
      Bearings::OutputFile.new(
        path: path(page),
        content: copy(files.fetch(page.source_path), page.document, rewrites(page, copies, site_url))
      )
    end
  end

  # @rbs page: Bearings::Site::Page
  # @rbs return: String
  def path(page)
    page.markdown_url.delete_prefix('/')
  end

  # @rbs document: Bearings::Document
  # @rbs return: Array[Integer]
  def fenced(document)
    [*document.code_blocks, *document.diagrams].flat_map do |block|
      (block.line..(block.line + block.code.lines.count + 1)).to_a
    end
  end

  private

  # @rbs page: Bearings::Site::Page
  # @rbs copies: Hash[String, String]
  # @rbs site_url: String?
  # @rbs return: Array[rewrite]
  def rewrites(page, copies, site_url)
    links = page.document.links.filter_map do |link|
      path, hash, fragment = link.href.partition('#')
      url = Bearings::RepoPath.resolve(page.source_path, path)&.then { |in_repo| copies[in_repo] }
      [link.href, link.line, "#{url}#{hash}#{fragment}"] if url
    end #: Array[rewrite]
    images = page.document.images.filter_map do |image|
      path = Bearings::RepoPath.resolve(page.source_path, image.src)
      [image.src, image.line, "#{site_url}#{Bearings::Images.url(path)}"] if path
    end #: Array[rewrite]
    links + images
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
    blank = lines.filter_map.with_index(1) { |line, number| number if line.strip.empty? }
    Set.new(fenced(document) + blank)
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
      if match[:attribute]
        pattern = Bearings::Images::SOURCE_URLS.fetch(match[:source].to_s)
        urls = match[:value].to_s.gsub(pattern) do |destination|
          url, left = take(left, destination, number, breaks)
          url || destination
        end
        next "#{match[:attribute]}#{urls}"
      end

      url, left = take(left, match[:destination], number, breaks)
      url ? "#{match[:lead]}#{url}" : match.to_s
    end
    [rewritten, left]
  end

  # @rbs unused: Array[rewrite]
  # @rbs destination: String?
  # @rbs number: Integer
  # @rbs breaks: Set[Integer]
  # @rbs return: [String?, Array[rewrite]]
  def take(unused, destination, number, breaks)
    # Each link or image kramdown found in this paragraph rewrites one destination; a copy in plain text
    # stays as written.
    found = unused.index { |candidate, at, _| candidate == destination && same_paragraph?(at, number, breaks) }
    return [nil, unused] unless found

    [unused.fetch(found).last, unused.reject.with_index { |_, index| index == found }]
  end
end
