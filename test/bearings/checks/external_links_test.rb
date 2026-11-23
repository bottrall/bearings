# frozen_string_literal: true

require 'test_helper'

describe Bearings::Checks::ExternalLinks do
  def http(results = {})
    Struct.new(:results, :requested) do
      def status(url)
        requested << url
        results.fetch(url, 200)
      end
    end.new(results, [])
  end

  def page(source_path, *hrefs)
    links = hrefs.map.with_index(3) { |href, line| Bearings::Document::Link.new(href:, line:) }
    document = Bearings::Document.new(
      title: 'Guide', headings: [], links:, code_blocks: [], code_spans: [], images: [], diagrams: [], body: ''
    )
    Bearings::Site::Page.new(
      title: 'Guide',
      slug: 'guide',
      description: nil,
      group_label: 'Guides',
      featured: false,
      num: '01',
      url: '/guides/guide/',
      markdown_url: '/guides/guide.md',
      canonical_url: nil,
      source_path:,
      edit_url: nil,
      previous_slug: nil,
      next_slug: nil,
      document:,
      extras: {}
    )
  end

  def site(*pages)
    details = Bearings::Manifest::Site.new(
      name: 'Bearings', summary: nil, url: nil, repo: nil, version: nil, namespaces: []
    )
    Bearings::Site.new(details:, version: nil, groups: [], pages:)
  end

  def problems(results, *hrefs)
    Bearings::Checks::ExternalLinks.call(site(page('docs/START.md', *hrefs)), http(results))
  end

  def failure(reason, timed_out: false)
    Bearings::Checks::ExternalLinks::Failure.new(reason:, timed_out:)
  end

  def problem(message, level: :error, hint: 'fix or remove the link')
    Bearings::Problem.new(check: 'external-links', level:, file: 'docs/START.md', line: 3, message:, hint:)
  end

  describe '.call' do
    it 'requests only http and https links' do
      client = http
      pages = [page('docs/START.md', 'https://a.example', 'HTTP://b.example', '../INSTALL.md', '#top', 'mailto:me@x.y')]
      Bearings::Checks::ExternalLinks.call(site(*pages), client)

      assert_equal %w[https://a.example HTTP://b.example], client.requested
    end

    it 'requests each distinct URL once, across every guide' do
      client = http
      pages = [page('docs/START.md', 'https://a.example', 'https://a.example'), page('docs/INSTALL.md', 'https://a.example')]
      Bearings::Checks::ExternalLinks.call(site(*pages), client)

      assert_equal ['https://a.example'], client.requested
    end

    it 'reports every occurrence of a failing URL at its guide and line' do
      pages = [page('docs/START.md', 'https://a.example', 'https://a.example'), page('docs/INSTALL.md', 'https://a.example')]
      problems = Bearings::Checks::ExternalLinks.call(site(*pages), http('https://a.example' => 404))

      assert_equal(
        [['docs/START.md', 3], ['docs/START.md', 4], ['docs/INSTALL.md', 3]],
        problems.map { |found| [found.file, found.line] }
      )
    end

    it 'reports nothing for a link that succeeds' do
      assert_empty problems({ 'https://a.example' => 204 }, 'https://a.example')
    end

    it 'reports a status outside 2xx as an error' do
      assert_equal [problem('https://a.example returned HTTP 404')],
                   problems({ 'https://a.example' => 404 }, 'https://a.example')
    end

    it 'reports a timeout as a warning' do
      assert_equal(
        [problem(
          'https://a.example could not be fetched: timed out after 10s',
          level: :warning,
          hint: 'the site may be slow or down; run the check again later'
        )],
        problems({ 'https://a.example' => failure('timed out after 10s', timed_out: true) }, 'https://a.example')
      )
    end

    it 'reports any other failure as an error' do
      assert_equal [problem('https://a.example could not be fetched: Connection refused')],
                   problems({ 'https://a.example' => failure('Connection refused') }, 'https://a.example')
    end
  end
end
