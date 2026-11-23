# frozen_string_literal: true

require 'test_helper'

describe Bearings::HtmlPages do
  def fixture(name)
    File.read(File.join(__dir__, '..', 'fixtures', 'layout', name))
  end

  def link(href, line) = Bearings::Document::Link.new(href:, line:)

  def page(title, slug, source, body:, links: [], **fields)
    Bearings::Site::Page.new(
      title:,
      slug:,
      description: "About #{title}",
      group_label: 'Start here',
      featured: false,
      num: '01',
      url: "/guides/#{slug}/",
      markdown_url: "/guides/#{slug}.md",
      canonical_url: nil,
      source_path: source,
      edit_url: nil,
      previous_slug: nil,
      next_slug: nil,
      document: Bearings::Document.new(
        title:,
        headings: [],
        links:,
        code_blocks: [],
        code_spans: [],
        images: [],
        diagrams: [],
        body:
      ),
      extras: {},
      **fields
    )
  end

  def install_body
    <<~HTML
      <h2 id="set-up">Set up <code>bearings</code></h2>
      <p><a href="START.md">a</a> <a href="reference/MANIFEST.md#keys">b</a> <a href="NOPE.md#x">c</a> <a href="https://example.com/x.md">d</a></p>
      <h3 id="detail">Detail</h3>
      <h2 id="next">Next</h2>
    HTML
  end

  def start = page('Start', 'start', 'docs/START.md', body: "<p>Begin.</p>\n", next_slug: 'install')

  def install
    page(
      'Install',
      'install',
      'docs/INSTALL.md',
      body: install_body,
      links: [link('START.md', 3), link('reference/MANIFEST.md#keys', 3), link('NOPE.md#x', 5),
              link('https://example.com/x.md', 7)],
      num: '02',
      previous_slug: 'start',
      next_slug: 'reference/manifest'
    )
  end

  def manifest_page
    page(
      'Manifest',
      'reference/manifest',
      'docs/reference/MANIFEST.md',
      body: %(<p><a href="../INSTALL.md">back</a> <img src="../images/flow.gif" alt="Flow" /></p>\n),
      links: [link('../INSTALL.md', 3)],
      group_label: 'Reference',
      previous_slug: 'install'
    )
  end

  def site
    pages = [start, install, manifest_page]
    Bearings::Site.new(
      details: Bearings::Manifest::Site.new(
        name: 'Bearings',
        summary: 'A themeless docs engine',
        url: 'https://bearings.example',
        repo: 'https://github.com/bottrall/bearings',
        version: 'lib/bearings/version.rb',
        namespaces: []
      ),
      version: '1.2.3',
      groups: [
        Bearings::Site::Group.new(label: 'Start here', pages: pages.take(2), extras: {}),
        Bearings::Site::Group.new(label: 'Reference', pages: pages.drop(2), extras: {})
      ],
      pages:
    )
  end

  def build(layout: '', landing: '', assets: {}, images: {})
    Bearings::HtmlPages.call(site, layout:, landing:, assets:, images:)
  end

  def files(...) = build(...).first

  def problems(...) = build(...).last

  def landing(template) = files(landing: template).first.content

  def guides(layout) = files(layout:).select { |file| file.path.start_with?('guides/') }.map(&:content)

  def guide(slug, layout, images: {})
    files(layout:, images:).find { |file| file.path == "guides/#{slug}/index.html" }&.content
  end

  describe '.call' do
    it 'writes the landing page, a page at each guide URL, then the assets' do
      assert_equal(
        %w[index.html guides/start/index.html guides/install/index.html guides/reference/manifest/index.html 404.html],
        files(assets: { '404.html' => Pathname('docs-site/404.html') }).map(&:path)
      )
    end

    it 'gives the landing page the groups' do
      assert_equal 'Start here,Reference', landing('<%= groups.map(&:label).join(",") %>')
    end

    it 'gives the landing page the pages' do
      assert_equal 'start,install,reference/manifest', landing('<%= pages.map(&:slug).join(",") %>')
    end

    it 'gives the landing page the version' do
      assert_equal '1.2.3', landing('<%= version %>')
    end

    it 'gives the landing page the site name, summary, URL and repo' do
      assert_equal(
        'Bearings|A themeless docs engine|https://bearings.example|https://github.com/bottrall/bearings',
        landing('<%= [site.name, site.summary, site.url, site.repo].join("|") %>')
      )
    end

    it 'gives each page the groups' do
      assert_equal 'Start here,Reference', guide('start', '<%= groups.map(&:label).join(",") %>')
    end

    it 'gives each page the pages' do
      assert_equal 'start,install,reference/manifest', guide('start', '<%= pages.map(&:slug).join(",") %>')
    end

    it 'gives each page the version' do
      assert_equal '1.2.3', guide('start', '<%= version %>')
    end

    it 'gives each page the site name, summary, URL and repo' do
      assert_equal(
        'Bearings|A themeless docs engine|https://bearings.example|https://github.com/bottrall/bearings',
        guide('start', '<%= [site.name, site.summary, site.url, site.repo].join("|") %>')
      )
    end

    it 'gives each page its own page' do
      assert_equal %w[start install reference/manifest], guides('<%= page.slug %>')
    end

    it "gives a page its guide's body" do
      assert_equal "<p>Begin.</p>\n", guide('start', '<%= body %>')
    end

    it 'leaves an external link to a markdown file as written' do
      assert_includes guide('install', '<%= body %>'), '<a href="https://example.com/x.md">d</a>'
    end

    it "resolves a link to another guide from the linking guide's folder" do
      assert_includes guide('reference/manifest', '<%= body %>'), '<a href="/guides/install/">back</a>'
    end

    it 'rewrites a link to another guide to its page URL' do
      assert_includes guide('install', '<%= body %>'), '<a href="/guides/start/">a</a>'
    end

    it 'keeps the fragment of a link to another guide' do
      assert_includes guide('install', '<%= body %>'), '<a href="/guides/reference/manifest/#keys">b</a>'
    end

    it 'leaves a link to a markdown file that is not a page as written' do
      assert_includes guide('install', '<%= body %>'), '<a href="NOPE.md#x">c</a>'
    end

    it "points an image at its asset, sized from the file, resolved from the guide's folder" do
      images = { 'docs/images/flow.gif' => "GIF89a\x03\x00\x02\x00" }

      assert_includes guide('reference/manifest', '<%= body %>', images:),
                      '<img src="/assets/docs/images/flow.gif" alt="Flow" width="3" height="2" loading="lazy" />'
    end

    it "gives a page the ids of its guide's h2 headings" do
      assert_equal 'set-up,next', guide('install', '<%= toc.map { |item| item[:id] }.join(",") %>')
    end

    it "gives a page the titles of its guide's h2 headings, without markup" do
      assert_equal 'Set up bearings,Next', guide('install', '<%= toc.map { |item| item[:title] }.join(",") %>')
    end

    it 'gives the first page no previous page' do
      assert_equal '', guide('start', '<%= prev_page&.slug %>')
    end

    it 'gives a page the page before it' do
      assert_equal 'start', guide('install', '<%= prev_page&.slug %>')
    end

    it 'gives the last page no next page' do
      assert_equal '', guide('reference/manifest', '<%= next_page&.slug %>')
    end

    it 'gives a page the page after it' do
      assert_equal 'reference/manifest', guide('install', '<%= next_page&.slug %>')
    end

    it 'gives each page the URL of the search index' do
      assert_equal Bearings::SearchIndex::URL, guide('start', '<%= search_index_url %>')
    end

    it "renders riffer-rig's layout unchanged" do
      assert_equal fixture('install.html'), guide('install', fixture('layout.html.erb'))
    end

    it 'copies each asset to its path' do
      assert_equal(
        Bearings::OutputFile.new(path: 'site.css', content: Pathname('docs-site/site.css')),
        files(assets: { 'site.css' => Pathname('docs-site/site.css') }).last
      )
    end

    it 'accepts an external link to a markdown file' do
      refute_includes problems.map(&:line), 7
    end

    it 'accepts a link to a page' do
      refute_includes problems.map(&:line), 3
    end

    it "reports a link to a markdown file that is not a page, at the link's line" do
      assert_equal(
        [Bearings::Problem.new(
          check: 'link',
          level: :error,
          file: 'docs/INSTALL.md',
          line: 5,
          message: 'links to `NOPE.md#x`, which is not a page',
          hint: 'point the link at a guide the manifest lists, or add that guide to the manifest'
        )],
        problems
      )
    end
  end
end
