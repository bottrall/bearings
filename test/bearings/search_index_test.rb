# frozen_string_literal: true

require 'test_helper'

describe Bearings::SearchIndex do
  def page(slug, body, headings: [])
    Bearings::Site::Page.new(
      title: slug.capitalize,
      slug:,
      description: nil,
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
        title: slug.capitalize,
        headings:,
        links: [],
        code_blocks: [],
        code_spans: [],
        images: [],
        diagrams: [],
        body:
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

  def index(*pages) = Bearings::SearchIndex.call(site(*pages))

  def entries(*pages) = JSON.parse(index(*pages).content)

  def section(html) = entries(page('start', %(<h2 id="section">Section</h2>\n\n#{html}\n))).first

  def start
    page(
      'start',
      <<~HTML
        <p>Intro text.</p>

        <h2 id="install">Install</h2>

        <p>Run it.</p>

        <h2 id="configure">Configure</h2>

        <p>Set it.</p>
      HTML
    )
  end

  describe '.call' do
    it 'writes the index to search.json' do
      assert_equal 'search.json', index(start).path
    end

    it 'gives layouts the URL the index is written to' do
      assert_equal "/#{index(start).path}", Bearings::SearchIndex::URL
    end

    it 'lists the pages in reading order' do
      pages = [page('b', "<p>Text.</p>\n"), page('a', "<p>Text.</p>\n")]

      assert_equal(%w[/guides/b/ /guides/a/], entries(*pages).map { |entry| entry['url'] })
    end

    it 'gives no entries for a page with an empty body' do
      assert_empty entries(page('start', ''))
    end

    it 'gives every entry the title of its page' do
      assert_equal(%w[Start Start Start], entries(start).map { |entry| entry['title'] })
    end

    it 'gives the text before the first heading an entry for the page itself' do
      assert_equal(
        { 'title' => 'Start', 'heading' => nil, 'text' => 'Intro text.', 'url' => '/guides/start/' },
        entries(start).first
      )
    end

    it 'gives no entry for the page itself when nothing comes before the first heading' do
      body = %(<h2 id="install">Install</h2>\n\n<p>Run it.</p>\n)

      assert_equal(['/guides/start/#install'], entries(page('start', body)).map { |entry| entry['url'] })
    end

    it 'gives each section an entry with its heading, its text and its URL with the anchor' do
      assert_equal(
        { 'title' => 'Start', 'heading' => 'Install', 'text' => 'Run it.', 'url' => '/guides/start/#install' },
        entries(start)[1]
      )
    end

    it 'ends a section at the next heading' do
      assert_equal 'Set it.', entries(start).last['text']
    end

    it 'starts a section at a heading of any level' do
      body = %w[h2 h3 h6 h1].map { |tag| %(<#{tag} id="#{tag}">#{tag}</#{tag}>\n) }.join

      assert_equal(%w[h2 h3 h6 h1], entries(page('start', body)).map { |entry| entry['heading'] })
    end

    it 'anchors each section at the id the page gives its heading' do
      headings = %w[install install-1].map.with_index(2) do |id, line|
        Bearings::Document::Heading.new(level: 2, id:, line:)
      end
      body = headings.map { |heading| %(<h2 id="#{heading.id}">Install</h2>\n) }.join

      assert_equal(
        headings.map { |heading| "/guides/start/##{heading.id}" },
        entries(page('start', body, headings:)).map { |entry| entry['url'] }
      )
    end

    it 'gives a heading that ends the body an empty text' do
      assert_equal '', entries(page('start', '<p>Intro</p><h2 id="end">End</h2>')).last['text']
    end

    it 'strips markup from the heading' do
      body = %(<h2 id="the-manifest--guides">The <code>manifest</code> &amp; <a href="GUIDES.md">guides</a></h2>\n)

      assert_equal 'The manifest & guides', entries(page('start', body)).first['heading']
    end

    it 'strips markup from the text' do
      html = '<p>Some <em>emphasis</em>, <code>code</code> and a <a href="LINK.md">link</a>.</p>'

      assert_equal 'Some emphasis, code and a link.', section(html)['text']
    end

    it 'decodes the entities in the text' do
      assert_equal 'a < b & c > d', section('<p>a &lt; b &amp; c &gt; d</p>')['text']
    end

    it 'includes a highlighted code block as its code' do
      html = '<div class="language-ruby highlighter-rouge"><div class="highlight"><pre class="highlight"><code>' \
             '<span class="n">y</span> <span class="o">&amp;&amp;</span> <span class="s2">"x"</span>' \
             "\n</code></pre></div></div>"

      assert_equal 'y && "x"', section(html)['text']
    end

    it 'collapses the whitespace between lines and blocks into single spaces' do
      html = "<p>One\ntwo</p>\n\n<ul>\n  <li>three</li>\n  <li>four</li>\n</ul>"

      assert_equal 'One two three four', section(html)['text']
    end
  end
end
