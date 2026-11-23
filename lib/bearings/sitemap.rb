# frozen_string_literal: true

module Bearings::Sitemap
  extend self

  # @rbs site: Bearings::Site
  # @rbs manifest_file: String
  # @rbs return: [Array[Bearings::OutputFile], Array[Bearings::Problem]]
  def call(site, manifest_file:)
    url = site.details.url
    return [[], [no_url(manifest_file)]] unless url

    root = "#{url.delete_suffix('/')}/"
    files = [
      Bearings::OutputFile.new(path: 'sitemap.xml', content: sitemap([root, *site.pages.filter_map(&:canonical_url)])),
      Bearings::OutputFile.new(path: 'robots.txt', content: robots("#{root}sitemap.xml"))
    ]
    [files, []]
  end

  private

  # @rbs manifest_file: String
  # @rbs return: Bearings::Problem
  def no_url(manifest_file)
    Bearings::Problem.new(
      check: 'sitemap',
      level: :warning,
      file: manifest_file,
      line: 1,
      message: 'has no `site.url`, so sitemap.xml and robots.txt were not written',
      hint: 'set `site.url` to the address the site is published at'
    )
  end

  # @rbs urls: Array[String]
  # @rbs return: String
  def sitemap(urls)
    entries = urls.map { |url| "  <url><loc>#{url.encode(xml: :text)}</loc></url>\n" }
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      #{entries.join}</urlset>
    XML
  end

  # @rbs sitemap_url: String
  # @rbs return: String
  def robots(sitemap_url)
    <<~TEXT
      User-agent: *
      Allow: /

      Sitemap: #{sitemap_url}
    TEXT
  end
end
