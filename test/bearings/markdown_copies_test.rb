# frozen_string_literal: true

require 'test_helper'

describe Bearings::MarkdownCopies do
  def files
    {
      'docs/START.md' => "# Start\n",
      'docs/INSTALL.md' => "# Install\n",
      'docs/reference/MANIFEST.md' => "# Manifest\n"
    }
  end

  def listed(source, slug)
    Bearings::Manifest::Page.new(source:, slug:, description: nil, featured: false, extras: {})
  end

  def manifest(url)
    Bearings::Manifest.new(
      site: Bearings::Manifest::Site.new(
        name: 'Bearings', summary: 'A themeless docs engine', url:, repo: nil, version: nil, namespaces: []
      ),
      groups: [
        Bearings::Manifest::Group.new(
          label: 'Guides',
          pages: [
            listed('docs/START.md', 'start'),
            listed('docs/INSTALL.md', 'install'),
            listed('docs/reference/MANIFEST.md', 'reference/manifest')
          ],
          extras: {}
        )
      ],
      watch: [],
      redirects: {},
      outputs: Bearings::Manifest::Outputs.new(llms_full: false),
      checks: Bearings::Manifest::Checks.new(image_limit_kb: 300, external_links: false)
    )
  end

  def copies(changed = {}, url: 'https://bearings.example')
    sources = files.merge(changed)
    site, = Bearings::Site.build(manifest: manifest(url), files: sources, markdown: Bearings::Kramdown)
    Bearings::MarkdownCopies.call(site, sources)
  end

  def start(body, **)
    copies({ 'docs/START.md' => "# Start\n\n#{body}" }, **).first.content
  end

  def manifest_page(body)
    copies({ 'docs/reference/MANIFEST.md' => "# Manifest\n\n#{body}" }).last.content
  end

  describe '.call' do
    it "writes each page at its markdown URL's path" do
      assert_equal %w[guides/start.md guides/install.md guides/reference/manifest.md], copies.map(&:path)
    end

    it 'copies a guide with nothing to rewrite byte for byte' do
      guide = "# Start  \r\n\r\nRead [the spec](https://spec.commonmark.org/).\r\n\r\n```sh\nbin/setup\n```\n\tdone"

      assert_equal guide, copies({ 'docs/START.md' => guide }).first.content
    end

    it "points a link to another guide at that guide's copy" do
      assert_equal "# Start\n\nRead [Install](/guides/install.md).\n", start("Read [Install](INSTALL.md).\n")
    end

    it 'keeps the fragment of a link to another guide' do
      assert_equal "# Start\n\n[Gems](/guides/install.md#gems)\n", start("[Gems](INSTALL.md#gems)\n")
    end

    it 'resolves a link that starts with ./' do
      assert_equal "# Start\n\n[Install](/guides/install.md)\n", start("[Install](./INSTALL.md)\n")
    end

    it 'resolves a link into a subfolder' do
      assert_equal "# Start\n\n[Manifest](/guides/reference/manifest.md)\n",
                   start("[Manifest](reference/MANIFEST.md)\n")
    end

    it 'resolves a link that climbs out of its folder with ../' do
      assert_equal "# Manifest\n\n[Start](/guides/start.md)\n", manifest_page("[Start](../START.md)\n")
    end

    it "keeps a link's title" do
      assert_equal "# Start\n\n[Install](/guides/install.md \"Set up\")\n", start("[Install](INSTALL.md \"Set up\")\n")
    end

    it "keeps a link's angle brackets" do
      assert_equal "# Start\n\n[Install](</guides/install.md>)\n", start("[Install](<INSTALL.md>)\n")
    end

    it 'rewrites a link whose text runs over two lines' do
      assert_equal "# Start\n\n[the install\nguide](/guides/install.md)\n", start("[the install\nguide](INSTALL.md)\n")
    end

    {
      'an external URL' => '[Install](https://example.com/INSTALL.md)',
      'a mailto link' => '[Mail](mailto:team@example.com)',
      'an absolute path' => '[Install](/guides/install/)',
      'a bare anchor' => '[Top](#start)',
      'a markdown file that is not a page' => '[Contributing](../CONTRIBUTING.md)',
      'a file that is not markdown' => '[Setup](../bin/setup)'
    }.each do |kind, link|
      it "leaves #{kind} as written" do
        assert_equal "# Start\n\n#{link}\n", start("#{link}\n")
      end
    end

    it "points an image at its asset under the site's URL" do
      assert_equal(
        "# Start\n\n![Logo](https://bearings.example/assets/docs/images/logo.png)\n",
        start("![Logo](images/logo.png)\n")
      )
    end

    it "resolves an image that climbs out of the guide's folder" do
      assert_equal(
        "# Start\n\n![Logo](https://bearings.example/assets/art/logo.png)\n",
        start("![Logo](../art/logo.png)\n")
      )
    end

    it "drops a trailing slash from the site's URL" do
      assert_equal(
        "# Start\n\n![Logo](https://bearings.example/assets/docs/logo.png)\n",
        start("![Logo](logo.png)\n", url: 'https://bearings.example/')
      )
    end

    it 'points an image at its root-relative asset when the site has no URL' do
      assert_equal "# Start\n\n![Logo](/assets/docs/logo.png)\n", start("![Logo](logo.png)\n", url: nil)
    end

    it 'leaves a root-relative image as written' do
      assert_equal "# Start\n\n![Logo](/images/logo.png)\n", start("![Logo](/images/logo.png)\n")
    end

    it 'leaves a remote image as written' do
      assert_equal "# Start\n\n![Logo](https://cdn.example/logo.png)\n", start("![Logo](https://cdn.example/logo.png)\n")
    end

    it 'rewrites a reference link at its definition' do
      assert_equal(
        "# Start\n\n[Install][setup]\n\n[setup]: /guides/install.md#gems \"Set up\"\n",
        start("[Install][setup]\n\n[setup]: INSTALL.md#gems \"Set up\"\n")
      )
    end

    it 'rewrites a reference image at its definition' do
      assert_equal(
        "# Start\n\n![Logo][logo]\n\n[logo]: https://bearings.example/assets/docs/logo.png\n",
        start("![Logo][logo]\n\n[logo]: logo.png\n")
      )
    end

    it 'leaves a link-shaped definition in a fenced code block as written' do
      assert_equal(
        "# Start\n\n[Install][setup]\n```\n[setup]: INSTALL.md\n```\n\n[setup]: /guides/install.md\n",
        start("[Install][setup]\n```\n[setup]: INSTALL.md\n```\n\n[setup]: INSTALL.md\n")
      )
    end

    it 'leaves a link in a fenced code block as written' do
      assert_equal(
        "# Start\n\n[Install](/guides/install.md)\n```md\n[Install](INSTALL.md)\n```\n",
        start("[Install](INSTALL.md)\n```md\n[Install](INSTALL.md)\n```\n")
      )
    end

    it 'leaves a link in an indented code block as written' do
      assert_equal(
        "# Start\n\n[Install](/guides/install.md)\n\n    [Install](INSTALL.md)\n",
        start("[Install](INSTALL.md)\n\n    [Install](INSTALL.md)\n")
      )
    end

    it 'leaves an escaped link as written when a real one follows it in the paragraph' do
      assert_equal(
        "# Start\n\n\\[Install](INSTALL.md) is plain text;\n[Install](/guides/install.md) is a link\n",
        start("\\[Install](INSTALL.md) is plain text;\n[Install](INSTALL.md) is a link\n")
      )
    end

    it 'leaves a link in inline code as written' do
      assert_equal(
        "# Start\n\n[Install](/guides/install.md) is written `[Install](INSTALL.md)`\n",
        start("[Install](INSTALL.md) is written `[Install](INSTALL.md)`\n")
      )
    end
  end
end
