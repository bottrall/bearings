# frozen_string_literal: true

require 'erb'
require 'pathname'

module Bearings::HtmlPages
  extend self

  # @rbs!
  #   type toc_entry = { id: String, title: String }

  GUIDE_LINK = /(?<path>[^":]+\.md)(?<fragment>#[^"]*)?/ #: Regexp
  GUIDE_HREF = /href="#{GUIDE_LINK}"/ #: Regexp
  WHOLE_GUIDE_LINK = /\A#{GUIDE_LINK}\z/ #: Regexp
  H2 = %r{<h2 id="([^"]+)"[^>]*>(.*?)</h2>}m #: Regexp

  # @rbs site: Bearings::Site
  # @rbs layout: String
  # @rbs landing: String
  # @rbs assets: Hash[String, Pathname]
  # @rbs images: Hash[String, String]
  # @rbs return: [Array[Bearings::OutputFile], Array[Bearings::Problem]]
  def call(site, layout:, landing:, assets:, images:)
    by_source = site.pages.to_h { |page| [page.source_path, page] }
    by_slug = site.pages.to_h { |page| [page.slug, page] }
    template = ERB.new(layout, trim_mode: '-')
    files = [
      landing_file(site, landing),
      *site.pages.map { |page| page_file(page, site, template, by_source, by_slug, images) },
      *assets.map { |path, source| Bearings::OutputFile.new(path:, content: source) }
    ]
    [files, site.pages.flat_map { |page| unknown_links(page, by_source) }]
  end

  private

  # @rbs site: Bearings::Site
  # @rbs return: Hash[Symbol, untyped]
  def shared(site)
    { groups: site.groups, pages: site.pages, version: site.version, site: site.details }
  end

  # @rbs site: Bearings::Site
  # @rbs landing: String
  # @rbs return: Bearings::OutputFile
  def landing_file(site, landing)
    html = ERB.new(landing, trim_mode: '-').result_with_hash(shared(site))
    Bearings::OutputFile.new(path: 'index.html', content: html)
  end

  # @rbs page: Bearings::Site::Page
  # @rbs site: Bearings::Site
  # @rbs layout: ERB
  # @rbs by_source: Hash[String, Bearings::Site::Page]
  # @rbs by_slug: Hash[String, Bearings::Site::Page]
  # @rbs images: Hash[String, String]
  # @rbs return: Bearings::OutputFile
  def page_file(page, site, layout, by_source, by_slug, images)
    body = Bearings::Images.html(rewrite_links(page, by_source), page.source_path, images)
    html = layout.result_with_hash(
      **shared(site),
      page:,
      body:,
      toc: toc(body),
      prev_page: neighbour(page.previous_slug, by_slug),
      next_page: neighbour(page.next_slug, by_slug),
      search_index_url: Bearings::SearchIndex::URL
    )
    Bearings::OutputFile.new(path: "#{page.url.delete_prefix('/')}index.html", content: html)
  end

  # @rbs page: Bearings::Site::Page
  # @rbs by_source: Hash[String, Bearings::Site::Page]
  # @rbs return: String
  def rewrite_links(page, by_source)
    page.document.body.gsub(GUIDE_HREF) do |href|
      match = Regexp.last_match #: MatchData
      path = match['path'] #: String
      target = by_source.fetch(resolve(page.source_path, path), nil)
      target ? %(href="#{target.url}#{match['fragment']}") : href
    end
  end

  # @rbs body: String
  # @rbs return: Array[toc_entry]
  def toc(body)
    headings = body.scan(H2) #: Array[[String, String]]
    headings.map { |id, title| { id:, title: title.gsub(Bearings::SearchIndex::TAG, '') } }
  end

  # @rbs slug: String?
  # @rbs by_slug: Hash[String, Bearings::Site::Page]
  # @rbs return: Bearings::Site::Page?
  def neighbour(slug, by_slug)
    by_slug[slug] if slug
  end

  # @rbs page: Bearings::Site::Page
  # @rbs by_source: Hash[String, Bearings::Site::Page]
  # @rbs return: Array[Bearings::Problem]
  def unknown_links(page, by_source)
    page.document.links.filter_map do |link|
      path = link.href[WHOLE_GUIDE_LINK, 'path']
      next unless path && !by_source.key?(resolve(page.source_path, path))

      Bearings::Problem.new(
        check: 'link',
        level: :error,
        file: page.source_path,
        line: link.line,
        message: "links to `#{link.href}`, which is not a page",
        hint: 'point the link at a guide the manifest lists, or add that guide to the manifest'
      )
    end
  end

  # @rbs source: String
  # @rbs path: String
  # @rbs return: String
  def resolve(source, path)
    Pathname(source).dirname.join(path).cleanpath.to_s
  end
end
