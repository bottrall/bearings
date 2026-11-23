# frozen_string_literal: true

require 'test_helper'

describe Bearings::Checks::Links do
  def link(href, line) = Bearings::Document::Link.new(href:, line:)

  def image(src, line) = Bearings::Document::Image.new(src:, alt: 'Logo', line:)

  def page(slug, source_path, links: [], images: [])
    document = Bearings::Document.new(
      title: 'Guide', headings: [], links:, code_blocks: [], code_spans: [], images:, diagrams: [], body: ''
    )
    Bearings::Site::Page.new(
      title: 'Guide',
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
      document:,
      extras: {}
    )
  end

  def install(...) = page('install', 'docs/INSTALL.md', ...)

  def start = page('start', 'docs/START.md')

  def site(pages, url)
    details = Bearings::Manifest::Site.new(
      name: 'Bearings', summary: nil, url:, repo: nil, version: nil, namespaces: []
    )
    Bearings::Site.new(details:, version: nil, groups: [], pages:)
  end

  def problems(files, pages: [], url: nil, sources: {}, markdown: Bearings::Kramdown)
    Bearings::Checks::Links.call(
      site(pages, url),
      files.map { |path, content| Bearings::OutputFile.new(path:, content:) },
      sources:,
      markdown:,
      layout_file: 'docs-site/layout.html.erb',
      landing_file: 'docs-site/index.html.erb',
      manifest_file: 'docs-site/manifest.yml'
    )
  end

  def located(...) = problems(...).map { |problem| [problem.file, problem.line] }

  def messages(...) = problems(...).map(&:message)

  describe '.call' do
    it 'reports a broken anchor in a link to another guide at the line that names the guide' do
      assert_equal(
        [['docs/INSTALL.md', 5]],
        located(
          { 'guides/install/index.html' => '<a href="/guides/start/#nope">x</a>', 'guides/start/index.html' => '' },
          pages: [install(links: [link('START.md#nope', 5)]), start]
        )
      )
    end

    it 'reports a broken link only at its own line, past a link to a path outside the repo' do
      assert_equal(
        [['docs/INSTALL.md', 3]],
        located(
          { 'guides/install/index.html' => '<a href="/LICENSE">x</a>' },
          pages: [install(links: [link('/LICENSE', 3), link('/NOTICE', 5)])]
        )
      )
    end

    it 'reports a broken link only at its own line, past a link to a markdown file that is not a guide' do
      assert_equal(
        [['docs/INSTALL.md', 3]],
        located(
          { 'guides/install/index.html' => '<a href="/LICENSE">x</a>' },
          pages: [install(links: [link('NOPE.md#x', 5), link('/LICENSE', 3)])]
        )
      )
    end

    it "reports a link written as raw HTML at its line in the guide's source" do
      assert_equal(
        [['docs/INSTALL.md', 5]],
        located(
          { 'guides/install/index.html' => '<a href="/nope/">x</a>' },
          pages: [install],
          sources: { 'docs/INSTALL.md' => %(# Install\n\nText.\n\n<a href="/nope/">x</a>\n) }
        )
      )
    end

    it 'reports a raw HTML link to another guide at its line in the guide, though the page rewrites it' do
      assert_equal(
        [['docs/INSTALL.md', 5]],
        located(
          { 'guides/install/index.html' => '<a href="/guides/start/#nope">x</a>', 'guides/start/index.html' => '' },
          pages: [install, start],
          sources: { 'docs/INSTALL.md' => %(# Install\n\nText.\n\n<a href="START.md#nope">x</a>\n) }
        )
      )
    end

    it 'reports a link in a page that the guide did not write at the layout' do
      assert_equal [['docs-site/layout.html.erb', 1]],
                   located({ 'guides/install/index.html' => '<link href="/site.css">' }, pages: [install])
    end

    it "reports the layout's link to a markdown file the site does not write" do
      assert_equal [['docs-site/layout.html.erb', 1]],
                   located({ 'guides/install/index.html' => '<a href="/guides/nope.md">x</a>' }, pages: [install])
    end

    it "skips a guide's link to a markdown file that is not a guide, which HtmlPages reports" do
      assert_empty problems(
        { 'guides/install/index.html' => '<a href="NOPE.md">x</a>' },
        pages: [install(links: [link('NOPE.md', 3)])]
      )
    end

    it "reports a broken link in a guide's page at the guide's line" do
      assert_equal(
        [Bearings::Problem.new(
          check: 'link',
          level: :error,
          file: 'docs/INSTALL.md',
          line: 3,
          message: 'links to `../LICENSE`, which is not a file in the site',
          hint: 'point the link at a page or file the site writes'
        )],
        problems(
          { 'guides/install/index.html' => '<a href="../LICENSE">x</a>' },
          pages: [install(links: [link('../LICENSE', 3)])]
        )
      )
    end

    it 'reports each line a guide writes the same broken link on' do
      assert_equal(
        [['docs/INSTALL.md', 3], ['docs/INSTALL.md', 7]],
        located(
          { 'guides/install/index.html' => '<a href="/LICENSE">x</a> <a href="/LICENSE">y</a>' },
          pages: [install(links: [link('/LICENSE', 3), link('/LICENSE', 7)])]
        )
      )
    end

    it "reports a broken link in a guide's markdown copy at the guide's line" do
      assert_equal [['docs/INSTALL.md', 3]],
                   located({ 'guides/install.md' => "# Install\n\nSee [the licence](../LICENSE).\n" }, pages: [install])
    end

    it "skips a copy's link to a markdown file that is not a guide, which HtmlPages reports" do
      assert_empty problems({ 'guides/install.md' => "# Install\n\nSee [x](NOPE.md).\n" }, pages: [install])
    end

    it 'reports a broken link on the landing page at the landing template' do
      assert_equal [['docs-site/index.html.erb', 1]], located({ 'index.html' => '<a href="/guides/missing/">x</a>' })
    end

    it 'reports a broken link in llms.txt at the manifest' do
      assert_equal [['docs-site/manifest.yml', 1]],
                   located(
                     { 'llms.txt' => "# Bearings\n\n- [Start](https://bearings.example/guides/start.md)\n" },
                     url: 'https://bearings.example'
                   )
    end

    it 'checks nothing in an output the site does not write' do
      assert_empty problems({}, pages: [install(links: [link('/LICENSE', 3)])])
    end

    it 'ignores HTML shown as code' do
      assert_empty problems({ 'index.html' => '<p><code>&lt;link href="/x.css"&gt;</code></p>' })
    end

    it 'reads the HTML entities in a link' do
      assert_empty problems({ 'index.html' => '<a href="/a&amp;b.html">x</a>', 'a&b.html' => '' })
    end

    it 'checks nothing in a markdown output the parser makes no document of' do
      markdown = Struct.new(:documents) { def document(source) = documents[source] }.new({})

      assert_empty problems({ 'guides/install.md' => "See [x](/LICENSE).\n" }, pages: [install], markdown:)
    end

    it "checks a link under the site's URL as a link into the site" do
      assert_equal ['links to `https://bearings.example/missing/`, which is not a file in the site'],
                   messages({ 'index.html' => '<a href="https://bearings.example/missing/">x</a>' }, url: 'https://bearings.example/')
    end

    it 'ignores external links' do
      assert_empty problems({ 'index.html' => '<a href="https://example.com/missing">x</a>' })
    end

    it 'ignores an external link on a site with a URL' do
      assert_empty problems(
        { 'index.html' => '<a href="https://example.com/missing">x</a>' }, url: 'https://bearings.example'
      )
    end

    it 'ignores a link with any other scheme' do
      assert_empty problems({ 'index.html' => '<a href="MAILTO:me@example.com">x</a>' })
    end

    it 'ignores a protocol-relative link' do
      assert_empty problems({ 'index.html' => '<a href="//example.com/missing">x</a>' })
    end

    it "leaves a guide's missing image in its page to Checks::Images" do
      assert_empty problems(
        { 'guides/install/index.html' => '<img src="/assets/docs/logo.png">' },
        pages: [install(images: [image('logo.png', 4)])]
      )
    end

    it "leaves a guide's missing image in its copy to Checks::Images" do
      assert_empty problems(
        { 'guides/install.md' => "# Install\n\n![Logo](https://bearings.example/assets/docs/logo.png)\n" },
        pages: [install(images: [image('logo.png', 3)])],
        url: 'https://bearings.example'
      )
    end

    it 'resolves a link with a query string to the file before it' do
      assert_empty problems({ 'index.html' => '<link href="/site.css?v=1">', 'site.css' => '' })
    end

    it 'resolves an anchor on the same page' do
      assert_empty problems({ 'index.html' => '<h2 id="top">Top</h2><a href="#top">x</a>' })
    end

    it 'resolves relative links against the linking page' do
      assert_empty problems(
        { 'guides/a/index.html' => '<a href="../b/">x</a>', 'guides/b/index.html' => '<p>b</p>' },
        pages: [page('a', 'docs/A.md')]
      )
    end

    it 'resolves a link to a folder to its index.html' do
      assert_empty problems({ 'index.html' => '<a href="/guides/b">x</a>', 'guides/b/index.html' => '<p>b</p>' })
    end

    it 'names the copy in a problem the copy has' do
      assert_equal ['its copy guides/install.md links to `../LICENSE`, which is not a file in the site'],
                   messages(
                     { 'guides/install.md' => "# Install\n\nSee [the licence](../LICENSE).\n" },
                     pages: [install]
                   )
    end

    it 'ignores an empty fragment' do
      assert_empty problems({ 'index.html' => '<a href="/guides/b/#">x</a>', 'guides/b/index.html' => '<p>b</p>' })
    end

    it 'does not check an anchor in a markdown copy' do
      assert_empty problems({ 'guides/install.md' => "# Install\n\nSee [x](#nowhere).\n" }, pages: [install])
    end

    it 'does not check an anchor in a file that is not HTML' do
      assert_empty problems({ 'index.html' => '<a href="/llms.txt#x">x</a>', 'llms.txt' => '# Bearings' })
    end

    it 'accepts an anchor in a copied file' do
      assert_empty problems(
        { 'index.html' => '<a href="/favicon.svg#dot">x</a>', 'favicon.svg' => Pathname('docs-site/favicon.svg') }
      )
    end

    it 'resolves an anchor on another page' do
      assert_empty problems(
        { 'index.html' => '<a href="/guides/b/#section">x</a>', 'guides/b/index.html' => '<h2 id="section">S</h2>' }
      )
    end

    it 'resolves an anchor in a file that is not a page' do
      assert_empty problems(
        { 'index.html' => '<a href="/favicon.svg#dot">x</a>',
          'favicon.svg' => '<svg id="dot"></svg>' }
      )
    end

    it 'reports a broken anchor' do
      assert_equal(
        [Bearings::Problem.new(
          check: 'anchor',
          level: :error,
          file: 'docs-site/index.html.erb',
          line: 1,
          message: 'links to `/guides/b/#no-such-anchor`, but guides/b/index.html has no id `no-such-anchor`',
          hint: "point the fragment at an id on that page, such as a heading's"
        )],
        problems(
          { 'index.html' => '<a href="/guides/b/#no-such-anchor">x</a>',
            'guides/b/index.html' => '<h2 id="section">S</h2>' }
        )
      )
    end

    it 'reports a broken link in the layout once, though every page holds it' do
      assert_equal(
        1,
        problems(
          { 'guides/install/index.html' => '<link href="/site.css">',
            'guides/start/index.html' => '<link href="/site.css">' },
          pages: [install, start]
        ).size
      )
    end
  end

  describe '.written' do
    it "lists a document's links, then its images, each with its line" do
      assert_equal [['a.md', 3], ['logo.png', 4]],
                   Bearings::Checks::Links.written(
                     install(
                       links: [link('a.md', 3)],
                       images: [image('logo.png', 4)]
                     ).document
                   )
    end
  end

  describe '.raw' do
    def raw(source, code_blocks: [])
      document = Bearings::Document.new(
        title: 'Guide', headings: [], links: [], code_blocks:, code_spans: [], images: [], diagrams: [], body: ''
      )
      Bearings::Checks::Links.raw(source, document)
    end

    it 'lists each href and src written as raw HTML, with its line' do
      assert_equal [['/a/', 3], ['b.png', 3]], raw(%(# Guide\n\n<a href="/a/"><img src="b.png"></a>\n))
    end

    it 'leaves out HTML in a fenced code block' do
      fence = Bearings::Document::CodeBlock.new(language: 'html', code: %(<a href="/a/">x</a>\n), line: 3)

      assert_empty raw(%(# Guide\n\n```html\n<a href="/a/">x</a>\n```\n), code_blocks: [fence])
    end

    it 'leaves out HTML in a code span' do
      assert_empty raw(%(# Guide\n\nWrite `<a href="/a/">` for a link.\n))
    end
  end

  describe '.ids' do
    it 'lists the ids in HTML' do
      assert_equal %w[top next], Bearings::Checks::Links.ids('<h2 id="top">Top</h2><p id="next">Next</p>')
    end

    it 'leaves out an id shown as code' do
      assert_empty Bearings::Checks::Links.ids('<pre><code class="language-text">&lt;h2 id="ghost"&gt;</code></pre>')
    end
  end
end
