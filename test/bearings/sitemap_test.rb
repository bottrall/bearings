# frozen_string_literal: true

require 'test_helper'

describe Bearings::Sitemap do
  def page(slug, canonical_url)
    Bearings::Site::Page.new(
      title: slug,
      slug:,
      description: nil,
      group_label: 'Guides',
      featured: false,
      num: '01',
      url: "/guides/#{slug}/",
      markdown_url: "/guides/#{slug}.md",
      canonical_url:,
      source_path: "docs/#{slug}.md",
      edit_url: nil,
      previous_slug: nil,
      next_slug: nil,
      document: Bearings::Document.new(
        title: slug, headings: [], links: [], code_blocks: [], code_spans: [], images: [], diagrams: [], body: ''
      ),
      extras: {}
    )
  end

  def guides
    [
      page('start', 'https://bearings.example/guides/start/'),
      page('reference/manifest', 'https://bearings.example/guides/reference/manifest/')
    ]
  end

  def site(url: 'https://bearings.example', pages: guides)
    Bearings::Site.new(
      details: Bearings::Manifest::Site.new(
        name: 'Bearings', summary: nil, url:, repo: nil, version: nil, namespaces: []
      ),
      version: nil,
      groups: [],
      pages:
    )
  end

  def call(site)
    Bearings::Sitemap.call(site, manifest_file: 'docs-site/manifest.yml')
  end

  def file(site, path)
    call(site).first.find { |output| output.path == path }
  end

  describe '.call' do
    describe 'without `site.url`' do
      it 'writes no files' do
        assert_empty call(site(url: nil)).first
      end

      it 'warns at the manifest that sitemap.xml and robots.txt were skipped' do
        problem = Bearings::Problem.new(
          check: 'sitemap',
          level: :warning,
          file: 'docs-site/manifest.yml',
          line: 1,
          message: 'has no `site.url`, so sitemap.xml and robots.txt were not written',
          hint: 'set `site.url` to the address the site is published at'
        )

        assert_equal [problem], call(site(url: nil)).last
      end
    end

    it 'joins a `site.url` that ends in a slash without doubling it' do
      assert_includes file(site(url: 'https://bearings.example/'), 'robots.txt').content,
                      'Sitemap: https://bearings.example/sitemap.xml'
    end

    it 'writes sitemap.xml listing the landing page and every guide by its canonical URL' do
      content = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
          <url><loc>https://bearings.example/</loc></url>
          <url><loc>https://bearings.example/guides/start/</loc></url>
          <url><loc>https://bearings.example/guides/reference/manifest/</loc></url>
        </urlset>
      XML

      assert_equal Bearings::OutputFile.new(path: 'sitemap.xml', content:), file(site, 'sitemap.xml')
    end

    it 'escapes each URL in sitemap.xml for XML' do
      escaped = site(url: 'https://bearings.example/r&d', pages: [])

      assert_includes file(escaped, 'sitemap.xml').content, '<loc>https://bearings.example/r&amp;d/</loc>'
    end

    it 'writes robots.txt that allows every crawler and names the sitemap' do
      content = <<~TEXT
        User-agent: *
        Allow: /

        Sitemap: https://bearings.example/sitemap.xml
      TEXT

      assert_equal Bearings::OutputFile.new(path: 'robots.txt', content:), file(site, 'robots.txt')
    end

    it 'reports no problems' do
      assert_empty call(site).last
    end
  end
end
