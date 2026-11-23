# frozen_string_literal: true

require 'test_helper'

describe Bearings::MarkdownCopies do
  def link(href, line = 3) = Bearings::Document::Link.new(href:, line:)

  def image(src, line = 3) = Bearings::Document::Image.new(src:, alt: 'Logo', line:)

  def code(code, line) = Bearings::Document::CodeBlock.new(language: nil, code:, line:)

  def diagram(code, line) = Bearings::Document::Diagram.new(code:, line:)

  def document(items)
    Bearings::Document.new(
      title: '',
      headings: [],
      links: items.grep(Bearings::Document::Link),
      code_blocks: items.grep(Bearings::Document::CodeBlock),
      images: items.grep(Bearings::Document::Image),
      diagrams: items.grep(Bearings::Document::Diagram),
      body: ''
    )
  end

  def page(slug, source_path, items = [])
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
      document: document(items),
      extras: {}
    )
  end

  def site(pages, url)
    Bearings::Site.new(
      details: Bearings::Manifest::Site.new(
        name: 'Bearings', summary: nil, url:, repo: nil, version: nil, namespaces: []
      ),
      version: nil,
      groups: [],
      pages:
    )
  end

  def files
    {
      'docs/START.md' => "# Start\n",
      'docs/INSTALL.md' => "# Install\n",
      'docs/reference/MANIFEST.md' => "# Manifest\n"
    }
  end

  def copies(changed = {}, start: [], manifest: [], url: 'https://bearings.example')
    pages = [
      page('start', 'docs/START.md', start),
      page('install', 'docs/INSTALL.md'),
      page('reference/manifest', 'docs/reference/MANIFEST.md', manifest)
    ]
    Bearings::MarkdownCopies.call(site(pages, url), files.merge(changed))
  end

  def start(body, *items, url: 'https://bearings.example')
    copies({ 'docs/START.md' => "# Start\n\n#{body}" }, start: items, url:).first.content
  end

  describe '.call' do
    it "writes each page at its markdown URL's path" do
      assert_equal %w[guides/start.md guides/install.md guides/reference/manifest.md], copies.map(&:path)
    end

    it 'copies a guide with nothing to rewrite byte for byte' do
      guide = "# Start  \r\n\r\nRead [the spec](https://spec.commonmark.org/).\r\n\r\n```sh\nbin/setup\n```\n\tdone"
      items = [link('https://spec.commonmark.org/'), code("bin/setup\n", 5)]

      assert_equal guide, copies({ 'docs/START.md' => guide }, start: items).first.content
    end

    it "drops a trailing slash from the site's URL" do
      assert_equal(
        "# Start\n\n![Logo](https://bearings.example/assets/docs/logo.png)\n",
        start("![Logo](logo.png)\n", image('logo.png'), url: 'https://bearings.example/')
      )
    end

    it 'points an image at its root-relative asset when the site has no URL' do
      assert_equal "# Start\n\n![Logo](/assets/docs/logo.png)\n",
                   start("![Logo](logo.png)\n", image('logo.png'), url: nil)
    end

    describe 'links' do
      {
        'an external URL' => 'https://example.com/INSTALL.md',
        'a bare anchor' => '#start',
        'a markdown file that is not a page' => '../CONTRIBUTING.md',
        'a file that is not markdown' => '../bin/setup'
      }.each do |kind, href|
        it "leaves #{kind} as written" do
          assert_equal "# Start\n\n[Link](#{href})\n", start("[Link](#{href})\n", link(href))
        end
      end

      it "points a link to another guide at that guide's copy" do
        assert_equal "# Start\n\nRead [Install](/guides/install.md).\n",
                     start("Read [Install](INSTALL.md).\n", link('INSTALL.md'))
      end

      it 'keeps the fragment of a link to another guide' do
        assert_equal "# Start\n\n[Gems](/guides/install.md#gems)\n",
                     start("[Gems](INSTALL.md#gems)\n", link('INSTALL.md#gems'))
      end

      it "resolves a link from its guide's folder" do
        guide = "# Manifest\n\n[Start](../START.md)\n"

        assert_equal "# Manifest\n\n[Start](/guides/start.md)\n",
                     copies({ 'docs/reference/MANIFEST.md' => guide }, manifest: [link('../START.md')]).last.content
      end
    end

    describe 'images' do
      it 'leaves a remote image as written' do
        assert_equal "# Start\n\n![Logo](https://cdn.example/logo.png)\n",
                     start("![Logo](https://cdn.example/logo.png)\n", image('https://cdn.example/logo.png'))
      end

      it "points an image at its asset under the site's URL" do
        assert_equal "# Start\n\n![Logo](https://bearings.example/assets/docs/images/logo.png)\n",
                     start("![Logo](images/logo.png)\n", image('images/logo.png'))
      end
    end

    describe 'copying' do
      it 'leaves a link-shaped definition in a fenced code block as written' do
        assert_equal(
          "# Start\n\n[Install][setup]\n```\n[setup]: INSTALL.md\n```\n\n[setup]: /guides/install.md\n",
          start(
            "[Install][setup]\n```\n[setup]: INSTALL.md\n```\n\n[setup]: INSTALL.md\n",
            link('INSTALL.md'),
            code("[setup]: INSTALL.md\n", 4)
          )
        )
      end

      it 'leaves a link in a fenced code block as written' do
        assert_equal(
          "# Start\n\n[Install](/guides/install.md)\n```md\n[Install](INSTALL.md)\n```\n",
          start(
            "[Install](INSTALL.md)\n```md\n[Install](INSTALL.md)\n```\n",
            link('INSTALL.md'),
            code("[Install](INSTALL.md)\n", 4)
          )
        )
      end

      it 'leaves a link in a mermaid diagram as written' do
        assert_equal(
          "# Start\n\n[Install](/guides/install.md)\n```mermaid\n[Install](INSTALL.md)\n```\n",
          start(
            "[Install](INSTALL.md)\n```mermaid\n[Install](INSTALL.md)\n```\n",
            link('INSTALL.md'),
            diagram("[Install](INSTALL.md)\n", 4)
          )
        )
      end

      it 'rewrites a reference link at its definition' do
        assert_equal(
          "# Start\n\n[Install][setup]\n\n[setup]: /guides/install.md#gems \"Set up\"\n",
          start("[Install][setup]\n\n[setup]: INSTALL.md#gems \"Set up\"\n", link('INSTALL.md#gems'))
        )
      end

      it 'rewrites a reference image at its definition' do
        assert_equal(
          "# Start\n\n![Logo][logo]\n\n[logo]: https://bearings.example/assets/docs/logo.png\n",
          start("![Logo][logo]\n\n[logo]: logo.png\n", image('logo.png'))
        )
      end

      it 'leaves a footnote that starts with a linked path as written' do
        assert_equal(
          "# Start\n\n[Install](/guides/install.md)[^1]\n\n[^1]: INSTALL.md\n",
          start("[Install](INSTALL.md)[^1]\n\n[^1]: INSTALL.md\n", link('INSTALL.md'))
        )
      end

      it "keeps a link's title" do
        assert_equal "# Start\n\n[Install](/guides/install.md \"Set up\")\n",
                     start("[Install](INSTALL.md \"Set up\")\n", link('INSTALL.md'))
      end

      it "keeps a link's angle brackets" do
        assert_equal "# Start\n\n[Install](</guides/install.md>)\n",
                     start("[Install](<INSTALL.md>)\n", link('INSTALL.md'))
      end

      it 'rewrites a link whose text runs over two lines' do
        assert_equal "# Start\n\n[the install\nguide](/guides/install.md)\n",
                     start("[the install\nguide](INSTALL.md)\n", link('INSTALL.md'))
      end

      it 'leaves a link in inline code as written' do
        assert_equal(
          "# Start\n\n[Install](/guides/install.md) is written `[Install](INSTALL.md)`\n",
          start("[Install](INSTALL.md) is written `[Install](INSTALL.md)`\n", link('INSTALL.md'))
        )
      end

      it 'leaves an escaped link as written when it comes before a real one on its line' do
        assert_equal(
          "# Start\n\n\\[Install](INSTALL.md) is plain text; [Install](/guides/install.md) is a link\n",
          start("\\[Install](INSTALL.md) is plain text; [Install](INSTALL.md) is a link\n", link('INSTALL.md'))
        )
      end

      it 'leaves a link as written when kramdown found it on a later line' do
        assert_equal(
          "# Start\n\nPlain [Install](INSTALL.md) text;\n[Install](/guides/install.md) is a link\n",
          start("Plain [Install](INSTALL.md) text;\n[Install](INSTALL.md) is a link\n", link('INSTALL.md', 4))
        )
      end

      it 'leaves a link as written when kramdown found it in an earlier paragraph' do
        assert_equal(
          "# Start\n\n[Install](/guides/install.md)\n\n    [Install](INSTALL.md)\n",
          start("[Install](INSTALL.md)\n\n    [Install](INSTALL.md)\n", link('INSTALL.md'))
        )
      end

      it 'rewrites only as many links as kramdown found' do
        assert_equal(
          "# Start\n\n[Install](/guides/install.md) is a link;\n[Install](INSTALL.md) is not\n",
          start("[Install](INSTALL.md) is a link;\n[Install](INSTALL.md) is not\n", link('INSTALL.md'))
        )
      end

      it 'points the src of a raw <img> at its asset' do
        assert_equal(
          %(# Start\n\n<img src="https://bearings.example/assets/docs/logo.png" alt="Logo">\n),
          start(%(<img src="logo.png" alt="Logo">\n), image('logo.png'))
        )
      end

      it 'points each URL in a srcset at its asset, keeping its descriptor' do
        assert_equal(
          %(# Start\n\n<source srcset="/assets/docs/dark.png 1x, /assets/docs/dark@2x.png 2x">\n),
          start(%(<source srcset="dark.png 1x, dark@2x.png 2x">\n), image('dark.png'), image('dark@2x.png'), url: nil)
        )
      end

      it 'leaves a src as written when kramdown found no image there' do
        assert_equal %(# Start\n\n    <img src="logo.png">\n), start(%(    <img src="logo.png">\n))
      end
    end
  end
end
