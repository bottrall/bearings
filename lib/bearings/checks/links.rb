# frozen_string_literal: true

require 'cgi/escape'
require 'pathname'

module Bearings::Checks::Links
  extend self

  # @rbs!
  #   type reference = [String, String, String, Integer]
  #   type located = [String, Integer]

  EXTERNAL = %r{#{Bearings::RepoPath::SCHEME}|\A//} #: Regexp
  ATTRIBUTE = /\b(?:href|src)="([^"]+)"/ #: Regexp
  CODE = %r{<code\b[^>]*>.*?</code>}m #: Regexp
  ID = /\bid="([^"]+)"/ #: Regexp
  LINK_HINT = 'point the link at a page or file the site writes' #: String
  ANCHOR_HINT = "point the fragment at an id on that page, such as a heading's" #: String

  # @rbs site: Bearings::Site
  # @rbs files: Array[Bearings::OutputFile]
  # @rbs sources: Hash[String, String]
  # @rbs markdown: Bearings::_Markdown
  # @rbs layout_file: String
  # @rbs landing_file: String
  # @rbs manifest_file: String
  # @rbs return: Array[Bearings::Problem]
  def call(site, files, sources:, markdown:, layout_file:, landing_file:, manifest_file:)
    contents = files.to_h { |file| [file.path, file.content] }
    texts = contents.select { |_, content| content.is_a?(String) } #: Hash[String, String]
    guides = site.pages.to_h { |page| [page.source_path, page] }
    references = [
      *site.pages.flat_map { |page| in_page(page, texts, guides, sources.fetch(page.source_path, ''), layout_file) },
      *site.pages.flat_map { |page| in_copy(page, texts, markdown) },
      *in_html('index.html', texts).map { |href| ['index.html', href, landing_file, 1] },
      *in_markdown('llms.txt', texts, markdown).map { |href, _| ['llms.txt', href, manifest_file, 1] }
    ] #: Array[reference]
    base = site.details.url&.delete_suffix('/')
    images = Set.new(site.pages.flat_map { |page| images(page) })
    references.filter_map { |reference| problem(reference, contents, texts, base, images) }.uniq
  end

  # @rbs document: Bearings::Document
  # @rbs return: Array[located]
  def written(document)
    [
      *document.links.map { |link| [link.href, link.line] },
      *document.images.map { |image| [image.src, image.line] }
    ]
  end

  # @rbs source: String
  # @rbs document: Bearings::Document
  # @rbs return: Array[located]
  def raw(source, document)
    # HTML shown as code is text in the guide, not a link.
    shown = Set.new(Bearings::MarkdownCopies.fenced(document))
    source.lines.each.with_index(1).flat_map do |line, number|
      next [] if shown.include?(number)

      attributes(line.gsub(Bearings::MarkdownCopies::CODE_SPAN, '')).map { |value| [value, number] }
    end
  end

  # @rbs html: String
  # @rbs return: Array[String]
  def ids(html)
    html.gsub(CODE, '').scan(ID).flatten
  end

  private

  # @rbs page: Bearings::Site::Page
  # @rbs texts: Hash[String, String]
  # @rbs guides: Hash[String, Bearings::Site::Page]
  # @rbs source: String
  # @rbs layout_file: String
  # @rbs return: Array[reference]
  def in_page(page, texts, guides, source, layout_file)
    from = Bearings::HtmlPages.path(page)
    written_at = by_form(page, written(page.document), guides)
    # The markdown parser lists no link written as raw HTML, so one is found in the guide's source.
    raw_at = by_form(page, raw(source, page.document), guides)
    in_html(from, texts).flat_map do |href|
      lines = written_at.fetch(href, [])
      next [unwritten(page, from, href, raw_at, layout_file)] if lines.empty?
      # HtmlPages reports a guide's link to a markdown file that is not a guide, and leaves it as written.
      next [] if Bearings::HtmlPages::WHOLE_GUIDE_LINK.match?(href)

      lines.map { |line| [from, href, page.source_path, line] }
    end
  end

  # @rbs page: Bearings::Site::Page
  # @rbs found: Array[located]
  # @rbs guides: Hash[String, Bearings::Site::Page]
  # @rbs return: Hash[String, Array[Integer]]
  def by_form(page, found, guides)
    forms = found.flat_map do |value, line|
      [value, *rewritten(page, value, guides)].map { |form| [form, line] }
    end #: Array[located]
    forms.group_by(&:first).transform_values { |pairs| pairs.map(&:last) }
  end

  # @rbs page: Bearings::Site::Page
  # @rbs source: String
  # @rbs guides: Hash[String, Bearings::Site::Page]
  # @rbs return: Array[String]
  def rewritten(page, source, guides)
    path, hash, fragment = source.partition('#')
    in_repo = Bearings::RepoPath.resolve(page.source_path, path)
    return [] unless in_repo

    # HtmlPages rewrites a guide's link to another guide before it reaches the page.
    guide = guides.fetch(in_repo, nil)
    guide ? ["#{guide.url}#{hash}#{fragment}"] : []
  end

  # @rbs page: Bearings::Site::Page
  # @rbs from: String
  # @rbs href: String
  # @rbs raw_at: Hash[String, Array[Integer]]
  # @rbs layout_file: String
  # @rbs return: reference
  def unwritten(page, from, href, raw_at, layout_file)
    line = raw_at.fetch(href, []).first
    line ? [from, href, page.source_path, line] : [from, href, layout_file, 1]
  end

  # @rbs page: Bearings::Site::Page
  # @rbs return: Array[String]
  def images(page)
    page.document.images.filter_map do |image|
      Bearings::RepoPath.resolve(page.source_path, image.src)&.then { |in_repo| Bearings::Images.url(in_repo) }
    end
  end

  # @rbs page: Bearings::Site::Page
  # @rbs texts: Hash[String, String]
  # @rbs markdown: Bearings::_Markdown
  # @rbs return: Array[reference]
  def in_copy(page, texts, markdown)
    from = Bearings::MarkdownCopies.path(page)
    # A copy keeps its guide's lines, so a link's line in the copy is its line in the guide.
    in_markdown(from, texts, markdown).filter_map do |href, line|
      # HtmlPages reports a link to a markdown file that is not a guide, which the copy leaves as written.
      [from, href, page.source_path, line] unless Bearings::HtmlPages::WHOLE_GUIDE_LINK.match?(href)
    end
  end

  # @rbs path: String
  # @rbs texts: Hash[String, String]
  # @rbs return: Array[String]
  def in_html(path, texts)
    attributes(texts.fetch(path, '')).uniq
  end

  # @rbs html: String
  # @rbs return: Array[String]
  def attributes(html)
    # HTML shown as code is text on the page, not a link.
    found = html.gsub(CODE, '').scan(ATTRIBUTE).flatten #: Array[String]
    found.map { |value| CGI.unescapeHTML(value) }
  end

  # @rbs path: String
  # @rbs texts: Hash[String, String]
  # @rbs markdown: Bearings::_Markdown
  # @rbs return: Array[located]
  def in_markdown(path, texts, markdown)
    text = texts[path]
    document = markdown.document(text) if text
    document ? written(document) : []
  end

  # @rbs reference: reference
  # @rbs contents: Hash[String, String | Pathname]
  # @rbs texts: Hash[String, String]
  # @rbs base: String?
  # @rbs images: Set[String]
  # @rbs return: Bearings::Problem?
  def problem(reference, contents, texts, base, images)
    from, href, file, line = reference
    local = base && href.start_with?("#{base}/") ? href.delete_prefix(base) : href
    return if EXTERNAL.match?(local)

    address, _, fragment = local.partition('#')
    path = address.partition('?').first
    # Checks::Images reports a guide's image that is missing, and Images writes every one that is not.
    return if images.include?(path)

    target = target(from, path, contents)
    unless target
      return failed(file, line, 'link', "#{subject(from)} `#{href}`, which is not a file in the site", LINK_HINT)
    end
    # A fragment in markdown names a heading on GitHub, and a copied file's ids can't be read without opening it.
    return if fragment.empty? || !from.end_with?('.html') || !target.end_with?('.html') || !texts.key?(target)
    return if ids(texts.fetch(target)).include?(fragment)

    failed(file, line, 'anchor', "links to `#{href}`, but #{target} has no id `#{fragment}`", ANCHOR_HINT)
  end

  # @rbs from: String
  # @rbs path: String
  # @rbs contents: Hash[String, String | Pathname]
  # @rbs return: String?
  def target(from, path, contents)
    return from if path.empty?

    resolved = Pathname("/#{from}").dirname.join(path).cleanpath
    candidates = [resolved, resolved.join('index.html')].map { |file| file.to_s.delete_prefix('/') }
    candidates.find { |file| contents.key?(file) }
  end

  # @rbs from: String
  # @rbs return: String
  def subject(from)
    from.end_with?('.md') ? "its copy #{from} links to" : 'links to'
  end

  # @rbs file: String
  # @rbs line: Integer
  # @rbs check: String
  # @rbs message: String
  # @rbs hint: String
  # @rbs return: Bearings::Problem
  def failed(file, line, check, message, hint)
    Bearings::Problem.new(check:, level: :error, file:, line:, message:, hint:)
  end
end
