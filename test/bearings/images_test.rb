# frozen_string_literal: true

require 'test_helper'

describe Bearings::Images do
  def gif(width, height) = "GIF89a#{[width, height].pack('v2')}"

  def image(src) = Bearings::Document::Image.new(src:, alt: 'Flow', line: 3)

  def page(slug, source_path, images)
    Bearings::Site::Page.new(
      title: '',
      slug:,
      description: nil,
      group_label: 'Guides',
      featured: false,
      num: '01',
      url: "/guides/#{slug}/",
      markdown_url: "/guides/#{slug}.md",
      canonical_url: nil,
      source_path:,
      edit_url: nil,
      previous_slug: nil,
      next_slug: nil,
      document: Bearings::Document.new(
        title: '', headings: [], links: [], code_blocks: [], code_spans: [], images:, diagrams: [], body: ''
      ),
      extras: {}
    )
  end

  def site(*pages)
    Bearings::Site.new(
      details: Bearings::Manifest::Site.new(
        name: 'Bearings', summary: nil, url: nil, repo: nil, version: nil, namespaces: []
      ),
      version: nil,
      groups: [],
      pages:
    )
  end

  def html(body, images = {}) = Bearings::Images.html(body, 'docs/START.md', images)

  describe '.url' do
    it 'gives the URL of the asset for a repo path' do
      assert_equal '/assets/docs/images/flow.svg', Bearings::Images.url('docs/images/flow.svg')
    end
  end

  describe '.paths' do
    it "resolves each image from its guide's folder" do
      pages = [page('start', 'docs/START.md', [image('images/flow.svg')]),
               page('manifest', 'docs/reference/MANIFEST.md', [image('../art/logo.png')])]

      assert_equal %w[docs/images/flow.svg docs/art/logo.png], Bearings::Images.paths(site(*pages))
    end

    it 'leaves out a remote image' do
      assert_empty Bearings::Images.paths(site(page('start', 'docs/START.md', [image('https://cdn.example/x.png')])))
    end

    it 'lists an image two guides share once' do
      pages = [page('start', 'docs/START.md', [image('images/flow.svg')]),
               page('install', 'docs/INSTALL.md', [image('./images/flow.svg')])]

      assert_equal %w[docs/images/flow.svg], Bearings::Images.paths(site(*pages))
    end
  end

  describe '.call' do
    it 'copies each image it is given under assets/, keeping its repo path' do
      files = Bearings::Images.call({ 'docs/images/flow.svg' => '<svg/>' })

      assert_equal(
        [Bearings::OutputFile.new(path: 'assets/docs/images/flow.svg', content: Pathname('docs/images/flow.svg'))],
        files
      )
    end
  end

  describe '.html' do
    it 'leaves a remote image as it is' do
      assert_equal '<img src="https://cdn.example/flow.gif" alt="Flow" />',
                   html('<img src="https://cdn.example/flow.gif" alt="Flow" />', { 'docs/flow.gif' => gif(3, 2) })
    end

    it 'leaves a remote image whose URL has a comma as it is' do
      assert_equal '<img src="https://cdn.example/w_100,h_100/flow.gif" alt="Flow" />',
                   html('<img src="https://cdn.example/w_100,h_100/flow.gif" alt="Flow" />')
    end

    it 'leaves a data: URI image as it is' do
      assert_equal '<img src="data:image/png;base64,iVBORw0KGgo/AAA+B,CCC=" alt="Flow" />',
                   html('<img src="data:image/png;base64,iVBORw0KGgo/AAA+B,CCC=" alt="Flow" />')
    end

    it 'points the srcset of an <img> with no src at its asset, adding nothing' do
      assert_equal '<img srcset="/assets/docs/flow.gif 2x" alt="Flow" />',
                   html('<img srcset="flow.gif 2x" alt="Flow" />', { 'docs/flow.gif' => gif(3, 2) })
    end

    it 'leaves an attribute other than src and srcset as it is' do
      assert_equal '<img src="https://cdn.example/flow.gif" alt="a.png" />',
                   html('<img src="https://cdn.example/flow.gif" alt="a.png" />')
    end

    it 'points each source in a <picture> at its asset, sizing only the <img>' do
      source = <<~HTML
        <picture>
          <source media="(prefers-color-scheme: dark)" srcset="dark.gif 1x, dark@2x.gif 2x" />
          <img src="light.gif" alt="Flow" />
        </picture>
      HTML
      images = { 'docs/dark.gif' => gif(3, 2), 'docs/light.gif' => gif(3, 2) }

      assert_equal <<~HTML, html(source, images)
        <picture>
          <source media="(prefers-color-scheme: dark)" srcset="/assets/docs/dark.gif 1x, /assets/docs/dark@2x.gif 2x" />
          <img src="/assets/docs/light.gif" alt="Flow" width="3" height="2" loading="lazy" />
        </picture>
      HTML
    end

    it 'keeps a srcset URL with a comma whole' do
      assert_equal '<source srcset="/assets/docs/w_100,h_100/flow.gif 2x, /assets/docs/flow.gif 1x" />',
                   html('<source srcset="w_100,h_100/flow.gif 2x, flow.gif 1x" />')
    end

    it 'keeps a src with a comma whole' do
      assert_equal '<img src="/assets/docs/a,b.gif" alt="Flow" width="3" height="2" loading="lazy" />',
                   html('<img src="a,b.gif" alt="Flow" />', { 'docs/a,b.gif' => gif(3, 2) })
    end

    it 'points an <img> at its asset, sized from its file, loading lazily' do
      assert_equal '<p><img src="/assets/docs/images/flow.gif" alt="Flow" width="3" height="2" loading="lazy" /></p>',
                   html('<p><img src="images/flow.gif" alt="Flow" /></p>', { 'docs/images/flow.gif' => gif(3, 2) })
    end

    it 'adds no width or height to an image whose file is missing' do
      assert_equal '<img src="/assets/docs/flow.gif" alt="Flow" loading="lazy" />',
                   html('<img src="flow.gif" alt="Flow" />')
    end

    it 'adds no width or height to an image whose size cannot be read' do
      assert_equal '<img src="/assets/docs/flow.svg" alt="Flow" loading="lazy" />',
                   html('<img src="flow.svg" alt="Flow" />', { 'docs/flow.svg' => '<svg/>' })
    end

    it 'keeps the width the guide gave an image, adding no height' do
      assert_equal '<img src="/assets/docs/flow.gif" width="10" loading="lazy" />',
                   html('<img src="flow.gif" width="10" />', { 'docs/flow.gif' => gif(3, 2) })
    end

    it 'keeps the loading the guide gave an image' do
      assert_equal '<img src="/assets/docs/flow.gif" loading="eager" width="3" height="2" />',
                   html('<img src="flow.gif" loading="eager" />', { 'docs/flow.gif' => gif(3, 2) })
    end
  end
end
