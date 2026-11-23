# frozen_string_literal: true

require 'pathname'

module Bearings::Checks::ReadmeLinks
  extend self

  # @rbs!
  #   type anchors = [String, Array[String]]

  FILE = 'README.md' #: String

  # @rbs site: Bearings::Site
  # @rbs files: Array[Bearings::OutputFile]
  # @rbs readme: String
  # @rbs paths: Array[String]
  # @rbs markdown: singleton(Bearings::Kramdown)
  # @rbs return: Array[Bearings::Problem]
  def call(site, files, readme:, paths:, markdown:)
    document = markdown.whole(readme)
    texts = files.to_h { |file| [file.path, file.content] }.select { |_, content| content.is_a?(String) } #: Hash[String, String]
    guides = site.pages.to_h do |page|
      built = Bearings::HtmlPages.path(page)
      [page.source_path, [built, Bearings::Checks::Links.ids(texts.fetch(built, ''))]]
    end #: Hash[String, anchors]
    own = [FILE, Bearings::Checks::Links.ids(document.body)] #: anchors
    internal(document, readme).filter_map { |href, line| problem(href, line, paths, guides, own) }
  end

  # @rbs readme: String
  # @rbs markdown: singleton(Bearings::Kramdown)
  # @rbs return: Array[String]
  def paths(readme, markdown:)
    internal(markdown.whole(readme), readme).filter_map { |href, _| repo_path(href) }.uniq
  end

  private

  # @rbs document: Bearings::Document
  # @rbs readme: String
  # @rbs return: Array[[String, Integer]]
  def internal(document, readme)
    found = [*Bearings::Checks::Links.written(document), *Bearings::Checks::Links.raw(readme, document)].uniq
    found.reject { |href, _| Bearings::Checks::Links::EXTERNAL.match?(href) }
  end

  # @rbs href: String
  # @rbs return: String?
  def repo_path(href)
    path = href.partition('#').first
    Pathname(path).cleanpath.to_s unless path.empty?
  end

  # @rbs href: String
  # @rbs line: Integer
  # @rbs paths: Array[String]
  # @rbs guides: Hash[String, anchors]
  # @rbs own: anchors
  # @rbs return: Bearings::Problem?
  def problem(href, line, paths, guides, own)
    file = repo_path(href)
    if file && !paths.include?(file)
      return failed(
        line,
        'link',
        "links to `#{href}`, which is not a file in the repo",
        'fix the path, or add the file'
      )
    end

    fragment = href.partition('#').last
    return if fragment.empty?

    anchors = file ? guides.fetch(file, nil) : own
    unless anchors
      return failed(
        line,
        'anchor',
        "links to `#{href}`, an anchor in a file that is not a guide",
        'link to the file without the anchor, or to an anchor in a guide'
      )
    end

    built, ids = anchors
    return if ids.include?(fragment)

    failed(
      line,
      'anchor',
      "links to `#{href}`, but #{built} has no id `#{fragment}`",
      Bearings::Checks::Links::ANCHOR_HINT
    )
  end

  # @rbs line: Integer
  # @rbs check: String
  # @rbs message: String
  # @rbs hint: String
  # @rbs return: Bearings::Problem
  def failed(line, check, message, hint)
    Bearings::Problem.new(check:, level: :error, file: FILE, line:, message:, hint:)
  end
end
