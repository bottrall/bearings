# frozen_string_literal: true

require 'test_helper'

describe Bearings::Pipeline do
  def manifest_yaml(url: 'https://bearings.example', redirect_to: '/guides/start/', namespaces: '[]')
    <<~YAML
      site:
        name: Bearings
        #{"url: #{url}" if url}
        namespaces: #{namespaces}
      watch:
        - docs
      redirects:
        /guides/begin/: #{redirect_to}
      groups:
        - label: Start here
          pages:
            - source: docs/START.md
              slug: start
              description: Where to begin
    YAML
  end

  def input(
    source: "# Start\n\nBegin.\n\n![Flow](flow.gif)\n",
    layout: '<%= body %>',
    watched: [],
    declared: Set.new,
    readme: nil,
    **manifest
  )
    parsed = Bearings::Manifest::Parser.parse(manifest_yaml(**manifest), file: 'docs-site/manifest.yml')
    sources = { 'docs/START.md' => source }
    site, = Bearings::Site.build(manifest: parsed, files: sources, markdown: Bearings::Kramdown)
    Bearings::Pipeline::Input.new(
      manifest: parsed,
      manifest_file: 'docs-site/manifest.yml',
      site:,
      sources:,
      images: { 'docs/flow.gif' => "GIF89a\x03\x00\x02\x00" },
      watched:,
      layout:,
      landing: '',
      not_found: '',
      layout_file: 'docs-site/layout.html.erb',
      landing_file: 'docs-site/index.html.erb',
      not_found_file: 'docs-site/404.html.erb',
      assets: {},
      declared:,
      readme:,
      readme_paths: []
    )
  end

  def run_defaults(...) = Bearings::Pipeline.call(input(...), outputs: Bearings::Pipeline::OUTPUTS, checks: [])

  def check_defaults(...)
    Bearings::Pipeline.call(input(...), outputs: Bearings::Pipeline::OUTPUTS, checks: Bearings::Pipeline::CHECKS).last
  end

  def file(path) = Bearings::OutputFile.new(path:, content: '')

  def problem(check)
    Bearings::Problem.new(check:, level: :error, file: 'docs/START.md', line: 1, message: '', hint: nil)
  end

  def failing(check) = ->(_) { [[], [problem(check)]] }

  describe '::OUTPUTS' do
    it 'writes the HTML pages, images, markdown copies, llms.txt, sitemap, redirect stubs and search index' do
      assert_equal(
        %w[index.html 404.html guides/start/index.html assets/docs/flow.gif guides/start.md llms.txt sitemap.xml
           robots.txt guides/begin/index.html search.json],
        run_defaults.first.map(&:path)
      )
    end

    it 'writes no HTML pages without a layout' do
      refute_includes run_defaults(layout: nil).first.map(&:path), 'index.html'
    end

    it 'sizes the images in the HTML pages from their files' do
      page = run_defaults.first.find { |file| file.path == 'guides/start/index.html' }

      assert_includes page.content, '<img src="/assets/docs/flow.gif" alt="Flow" width="3" height="2" loading="lazy" />'
    end

    it 'reports the problems the outputs find' do
      assert_equal %w[llms sitemap], run_defaults(url: nil).last.map(&:check)
    end
  end

  describe '::CHECKS' do
    it 'reports nothing for a site with no problems' do
      assert_empty check_defaults(watched: ['docs/START.md'])
    end

    it 'reports a guide in a watched folder that no page lists' do
      assert_equal ['unlisted'], check_defaults(watched: ['docs/START.md', 'docs/OTHER.md']).map(&:check)
    end

    it 'reports a code example that does not parse' do
      assert_equal ['code'], check_defaults(source: "# Start\n\n```ruby\ndef\n```\n").map(&:check)
    end

    it 'reports a diagram that is empty' do
      assert_equal ['diagram'], check_defaults(source: "# Start\n\n```mermaid\n```\n").map(&:check)
    end

    it 'reports a constant the signatures do not declare' do
      assert_equal(
        ['constant'],
        check_defaults(
          source: "# Start\n\nSee `Bearings::Nope`.\n",
          namespaces: '[Bearings]',
          declared: Set['Bearings']
        ).map(&:check)
      )
    end

    it 'reports an image with no alt text' do
      assert_equal ['image'], check_defaults(source: "# Start\n\n![](flow.gif)\n").map(&:check)
    end

    it 'reports a redirect to a page the site does not have' do
      assert_equal ['redirect'], check_defaults(redirect_to: '/guides/gone/').map(&:check)
    end

    it 'reports a link to a file the site does not write' do
      assert_equal ['link'], check_defaults(source: "# Start\n\nSee [the licence](/LICENSE).\n").map(&:check).uniq
    end

    it 'reports a link in the README to a file the repo does not have' do
      assert_equal ['link'], check_defaults(readme: "# Readme\n\nSee [the licence](LICENSE).\n").map(&:check)
    end
  end

  describe '.call' do
    def call(outputs: [], checks: []) = Bearings::Pipeline.call(input, outputs:, checks:)

    it 'returns the files of every output' do
      assert_equal(
        %w[a.html b.html c.html],
        call(outputs: [->(_) { [[file('a.html'), file('b.html')], []] }, ->(_) { [[file('c.html')], []] }])
          .first.map(&:path)
      )
    end

    it 'returns the problems of every output' do
      assert_equal %w[a b], call(outputs: [failing('a'), failing('b')]).last.map(&:check)
    end

    it 'gives each check the files of every output' do
      assert_equal(
        %w[a.html b.html],
        call(
          outputs: [->(_) { [[file('a.html')], []] }, ->(_) { [[file('b.html')], []] }],
          checks: [->(_, files) { files.map { |output| problem(output.path) } }]
        ).last.map(&:check)
      )
    end

    it 'returns the problems of the outputs, then of every check' do
      assert_equal(
        %w[output a b],
        call(
          outputs: [failing('output')],
          checks: [->(_, _) { [problem('a')] }, ->(_, _) { [problem('b')] }]
        ).last.map(&:check)
      )
    end
  end
end
