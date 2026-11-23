# frozen_string_literal: true

require 'test_helper'

describe Bearings::LlmsTxt do
  def page(slug, title, description)
    Bearings::Site::Page.new(
      title:,
      slug:,
      description:,
      group_label: 'Guides',
      featured: false,
      num: '01',
      url: "/guides/#{slug}/",
      markdown_url: "/guides/#{slug}.md",
      canonical_url: nil,
      source_path: "docs/#{slug}.md",
      edit_url: nil,
      previous_slug: nil,
      next_slug: nil,
      document: Bearings::Document.new(
        title:, headings: [], links: [], code_blocks: [], code_spans: [], images: [], diagrams: [], body: ''
      ),
      extras: {}
    )
  end

  def groups(description: 'Install the gem and build a first site.')
    [
      Bearings::Site::Group.new(label: 'Getting started', pages: [page('start', 'Start', description)], extras: {}),
      Bearings::Site::Group.new(
        label: 'Reference',
        pages: [
          page('reference/manifest', 'The manifest', 'Every key the manifest takes.'),
          page('reference/checks', 'Checks', 'What each check reports.')
        ],
        extras: {}
      )
    ]
  end

  def site(url: 'https://bearings.example', summary: 'A themeless docs engine.', groups: self.groups)
    Bearings::Site.new(
      details: Bearings::Manifest::Site.new(
        name: 'Bearings', summary:, url:, repo: nil, version: nil, namespaces: []
      ),
      version: nil,
      groups:,
      pages: groups.flat_map(&:pages)
    )
  end

  def copies
    [
      Bearings::OutputFile.new(path: 'guides/start.md', content: "# Start\n\nRun `bin/setup`.\n"),
      Bearings::OutputFile.new(path: 'guides/reference/manifest.md', content: "# The manifest\n\nIt is YAML."),
      Bearings::OutputFile.new(path: 'guides/reference/checks.md', content: "# Checks\n")
    ]
  end

  def call(site, full: false)
    Bearings::LlmsTxt.call(site, copies, full:, manifest_file: 'docs-site/manifest.yml')
  end

  def file(site, path, full: false)
    call(site, full:).first.find { |output| output.path == path }
  end

  describe '.call' do
    describe 'without `site.url`' do
      it 'writes no llms.txt' do
        assert_nil file(site(url: nil), 'llms.txt')
      end

      it 'still writes llms-full.txt when it is on' do
        refute_nil file(site(url: nil), 'llms-full.txt', full: true)
      end

      it 'warns at the manifest that llms.txt was skipped' do
        problem = Bearings::Problem.new(
          check: 'llms',
          level: :warning,
          file: 'docs-site/manifest.yml',
          line: 1,
          message: 'has no `site.url`, so llms.txt was not written',
          hint: 'set `site.url` to the address the site is published at'
        )

        assert_equal [problem], call(site(url: nil)).last
      end
    end

    it 'joins a `site.url` that ends in a slash without doubling it' do
      assert_includes file(site(url: 'https://bearings.example/'), 'llms.txt').content,
                      '(https://bearings.example/guides/start.md)'
    end

    it "writes llms.txt with the site's name and summary and a section per group linking each markdown copy" do
      content = <<~TEXT
        # Bearings

        > A themeless docs engine.

        ## Getting started

        - [Start](https://bearings.example/guides/start.md): Install the gem and build a first site.

        ## Reference

        - [The manifest](https://bearings.example/guides/reference/manifest.md): Every key the manifest takes.
        - [Checks](https://bearings.example/guides/reference/checks.md): What each check reports.
      TEXT

      assert_equal Bearings::OutputFile.new(path: 'llms.txt', content:), file(site, 'llms.txt')
    end

    it 'leaves out the summary line when the site has no summary' do
      content = <<~TEXT
        # Bearings

        ## Getting started

        - [Start](https://bearings.example/guides/start.md): Install the gem and build a first site.
      TEXT

      assert_equal content, file(site(summary: nil, groups: groups.first(1)), 'llms.txt').content
    end

    it 'ends an entry at its link when the page has no description' do
      assert_includes file(site(groups: groups(description: nil)), 'llms.txt').content,
                      "- [Start](https://bearings.example/guides/start.md)\n"
    end

    it 'writes no llms-full.txt when it is off' do
      assert_nil file(site, 'llms-full.txt')
    end

    it 'writes llms-full.txt with every markdown copy in reading order, a blank line between each' do
      content = <<~MARKDOWN
        # Start

        Run `bin/setup`.

        # The manifest

        It is YAML.

        # Checks
      MARKDOWN

      assert_equal Bearings::OutputFile.new(path: 'llms-full.txt', content:), file(site, 'llms-full.txt', full: true)
    end

    it 'reports no problems' do
      assert_empty call(site).last
    end
  end
end
