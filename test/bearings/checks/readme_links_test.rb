# frozen_string_literal: true

require 'test_helper'

describe Bearings::Checks::ReadmeLinks do
  def page(slug, source_path)
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
      document: Bearings::Document.new(
        title: 'Guide', headings: [], links: [], code_blocks: [], code_spans: [], images: [], diagrams: [], body: ''
      ),
      extras: {}
    )
  end

  def guide_site
    details = Bearings::Manifest::Site.new(
      name: 'Bearings', summary: nil, url: nil, repo: nil, version: nil, namespaces: []
    )
    Bearings::Site.new(details:, version: nil, groups: [], pages: [page('a', 'docs/A.md')])
  end

  def problems(body, paths: [], title: "# Readme\n\n")
    Bearings::Checks::ReadmeLinks.call(
      guide_site,
      [Bearings::OutputFile.new(path: 'guides/a/index.html', content: '<h2 id="section">Section</h2>')],
      readme: "#{title}#{body}",
      paths:,
      markdown: Bearings::Kramdown
    )
  end

  def messages(...) = problems(...).map(&:message)

  describe '.call' do
    it 'checks a README whose title is not a "# " line' do
      assert_equal [4], problems("[x](MISSING.md)\n", title: "Readme\n======\n\n").map(&:line)
    end

    it 'checks a link written as raw HTML, at its line' do
      assert_equal [3], problems(%(<a href="MISSING.md">x</a>\n)).map(&:line)
    end

    it 'checks a raw HTML image the markdown also lists once' do
      assert_equal 1, problems(%(<img src="logo.png" alt="Logo">\n)).size
    end

    it 'ignores external links' do
      assert_empty problems("[x](https://example.com/missing)\n")
    end

    it "reports a link to a missing file at the link's line" do
      assert_equal(
        [Bearings::Problem.new(
          check: 'link',
          level: :error,
          file: 'README.md',
          line: 3,
          message: 'links to `docs/MISSING.md`, which is not a file in the repo',
          hint: 'fix the path, or add the file'
        )],
        problems("[x](docs/MISSING.md)\n")
      )
    end

    it 'resolves a link to a file without a fragment' do
      assert_empty problems("[x](LICENSE.txt)\n", paths: ['LICENSE.txt'])
    end

    it 'resolves a link through the path it names' do
      assert_empty problems("[x](./docs/)\n", paths: ['docs'])
    end

    it 'ignores an empty fragment' do
      assert_empty problems("[x](#)\n")
    end

    it 'reports an anchor into a file that is not a guide' do
      assert_equal(
        [Bearings::Problem.new(
          check: 'anchor',
          level: :error,
          file: 'README.md',
          line: 3,
          message: 'links to `CHANGELOG.md#v1`, an anchor in a file that is not a guide',
          hint: 'link to the file without the anchor, or to an anchor in a guide'
        )],
        problems("[x](CHANGELOG.md#v1)\n", paths: ['CHANGELOG.md'])
      )
    end

    it 'resolves an anchor on the README itself' do
      assert_empty problems("## Install\n\n[x](#install)\n")
    end

    it "resolves an anchor into a guide against the guide's page" do
      assert_empty problems("[x](docs/A.md#section)\n", paths: ['docs/A.md'])
    end

    it 'reports an anchor missing from the README itself' do
      assert_equal ['links to `#nowhere`, but README.md has no id `nowhere`'], messages("[x](#nowhere)\n")
    end

    it "reports an anchor missing from its guide's page" do
      assert_equal(
        [Bearings::Problem.new(
          check: 'anchor',
          level: :error,
          file: 'README.md',
          line: 3,
          message: 'links to `docs/A.md#nowhere`, but guides/a/index.html has no id `nowhere`',
          hint: "point the fragment at an id on that page, such as a heading's"
        )],
        problems("[x](docs/A.md#nowhere)\n", paths: ['docs/A.md'])
      )
    end
  end

  describe '.paths' do
    def paths(body) = Bearings::Checks::ReadmeLinks.paths("# Readme\n\n#{body}", markdown: Bearings::Kramdown)

    it 'leaves out external links' do
      assert_empty paths("[x](https://example.com/a.md)\n")
    end

    it 'leaves out an anchor on the README itself' do
      assert_empty paths("[x](#install)\n")
    end

    it 'lists each repo path the README links to once, without its fragment' do
      assert_equal %w[docs/A.md logo.png], paths("[a](./docs/A.md#x) [b](docs/A.md) ![c](logo.png)\n")
    end
  end
end
