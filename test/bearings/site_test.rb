# frozen_string_literal: true

require 'test_helper'

describe Bearings::Site do
  def document(title)
    Bearings::Document.new(
      title:,
      headings: [],
      links: [],
      code_blocks: [],
      code_spans: [],
      images: [],
      diagrams: [],
      body: ''
    )
  end

  def markdown
    documents = %w[Start Install Manifest Layout].to_h { |title| ["# #{title}\n", document(title)] }
    Struct.new(:documents) { def document(source) = documents[source] }.new(documents)
  end

  def files
    {
      'lib/bearings/version.rb' => "module Bearings\n  VERSION = '1.2.3'\nend\n",
      'docs/START.md' => "# Start\n",
      'docs/INSTALL.md' => "# Install\n",
      'docs/reference/MANIFEST.md' => "# Manifest\n",
      'docs/LAYOUT.md' => "# Layout\n"
    }
  end

  def listed(source, slug, **fields)
    Bearings::Manifest::Page.new(source:, slug:, description: nil, featured: false, extras: {}, **fields)
  end

  def groups
    [
      Bearings::Manifest::Group.new(
        label: 'Start here',
        pages: [
          listed('docs/START.md', 'start', description: 'Build a site', featured: true, extras: { 'badge' => 'new' }),
          listed('docs/INSTALL.md', 'install')
        ],
        extras: { 'tone' => 'teal' }
      ),
      Bearings::Manifest::Group.new(
        label: 'Reference',
        pages: [listed('docs/reference/MANIFEST.md', 'reference/manifest'), listed('docs/LAYOUT.md', 'layout')],
        extras: {}
      )
    ]
  end

  def manifest(**site)
    Bearings::Manifest.new(
      site: Bearings::Manifest::Site.new(
        name: 'Bearings',
        summary: 'A themeless docs engine',
        url: 'https://bearings.example',
        repo: 'https://github.com/bottrall/bearings',
        version: 'lib/bearings/version.rb',
        namespaces: [],
        **site
      ),
      groups:,
      watch: [],
      redirects: [],
      outputs: Bearings::Manifest::Outputs.new(llms_full: false),
      checks: Bearings::Manifest::Checks.new(image_limit_kb: 300, external_links: false)
    )
  end

  def build(manifest: self.manifest, files: self.files)
    Bearings::Site.build(manifest:, files:, markdown:)
  end

  def site(...) = build(...).first

  def problems(...) = build(...).last

  def pages(...) = site(...).pages

  def no_version
    Bearings::Problem.new(
      check: 'version',
      level: :error,
      file: 'lib/bearings/version.rb',
      line: 1,
      message: 'has no version',
      hint: "set VERSION = '…' in it, or point `site.version` at the file that does"
    )
  end

  def without_install = files.except('docs/INSTALL.md')

  def versionless = files.merge('lib/bearings/version.rb' => "module Bearings\nend\n")

  def untitled_install = files.merge('docs/INSTALL.md' => "Text\n")

  describe '.build' do
    it 'gives no version when the manifest names no version file' do
      assert_nil site(manifest: manifest(version: nil)).version
    end

    it 'reports a version file that is not in files' do
      assert_equal [no_version], problems(files: files.except('lib/bearings/version.rb'))
    end

    it 'reports a version file with no version in it' do
      assert_equal [no_version], problems(files: versionless)
    end

    it 'gives no version when the version file has none' do
      assert_nil site(files: versionless).version
    end

    it "reads the version from the version file's text" do
      assert_equal '1.2.3', site.version
    end

    it 'numbers pages per source folder, in reading order' do
      assert_equal %w[01 02 01 03], pages.map(&:num)
    end

    it 'keeps the number of a page that follows one left out' do
      assert_equal %w[01 01 03], pages(files: without_install).map(&:num)
    end

    it 'lists every page in reading order, across groups' do
      assert_equal %w[start install reference/manifest layout], pages.map(&:slug)
    end

    it 'reports a listed source that is not in files' do
      assert_equal(
        [Bearings::Problem.new(
          check: 'source',
          level: :error,
          file: 'docs/INSTALL.md',
          line: 1,
          message: 'is listed in the manifest but was not found',
          hint: 'add the file, or remove its page from the manifest'
        )],
        problems(files: without_install)
      )
    end

    it 'leaves out a page whose source is not in files' do
      assert_equal %w[start reference/manifest layout], pages(files: without_install).map(&:slug)
    end

    it 'reports the problem the guide gives' do
      assert_equal [Bearings::Guide.parse('docs/INSTALL.md', "Text\n", markdown)], problems(files: untitled_install)
    end

    it 'leaves out a page whose guide gives a problem' do
      assert_equal %w[start reference/manifest layout], pages(files: untitled_install).map(&:slug)
    end

    it 'gives a page its title, its document and its manifest entry' do
      assert_equal(
        {
          title: 'Start',
          slug: 'start',
          description: 'Build a site',
          group_label: 'Start here',
          featured: true,
          source_path: 'docs/START.md',
          document: document('Start'),
          extras: { 'badge' => 'new' }
        },
        pages.first.to_h.slice(:title, :slug, :description, :group_label, :featured, :source_path, :document, :extras)
      )
    end

    it 'gives a page the URL of its HTML page' do
      assert_equal '/guides/reference/manifest/', pages[2].url
    end

    it 'gives a page the URL of its markdown copy' do
      assert_equal '/guides/reference/manifest.md', pages[2].markdown_url
    end

    it 'gives a page no canonical URL when the site has no URL' do
      assert_nil pages(manifest: manifest(url: nil)).first.canonical_url
    end

    it 'gives a page a canonical URL under the site URL' do
      assert_equal 'https://bearings.example/guides/start/', pages.first.canonical_url
    end

    it 'ignores a slash at the end of the site URL' do
      assert_equal(
        'https://bearings.example/guides/start/',
        pages(manifest: manifest(url: 'https://bearings.example/')).first.canonical_url
      )
    end

    it 'gives a page no edit URL when the site has no repo' do
      assert_nil pages(manifest: manifest(repo: nil)).first.edit_url
    end

    it 'gives a page an edit URL for its source on the main branch of the repo' do
      assert_equal 'https://github.com/bottrall/bearings/edit/main/docs/START.md', pages.first.edit_url
    end

    it 'gives the first page no previous page' do
      assert_nil pages.first.previous_slug
    end

    it 'gives a page the slug of the page before it' do
      assert_equal 'install', pages[2].previous_slug
    end

    it 'gives a page the slug of the page after it' do
      assert_equal 'reference/manifest', pages[1].next_slug
    end

    it 'gives the last page no next page' do
      assert_nil pages.last.next_slug
    end

    it 'links the pages either side of one left out' do
      assert_equal 'reference/manifest', pages(files: without_install).first.next_slug
    end

    it 'reports no problems for a site with every file' do
      assert_empty problems
    end

    it 'reports the version file and every page in one run' do
      assert_equal %w[version source source source source], problems(files: {}).map(&:check)
    end

    it "holds the manifest's site details" do
      assert_equal manifest.site, site.details
    end

    it 'gives each group its label, its pages and its extra manifest keys' do
      assert_equal(
        [['Start here', %w[start install], { 'tone' => 'teal' }], ['Reference', %w[reference/manifest layout], {}]],
        site.groups.map { |group| [group.label, group.pages.map(&:slug), group.extras] }
      )
    end

    it 'gives a group the same pages the site lists' do
      assert_equal pages, site.groups.flat_map(&:pages)
    end

    it 'keeps a group whose pages are all left out' do
      assert_equal [[], []], site(files: {}).groups.map(&:pages)
    end
  end
end
