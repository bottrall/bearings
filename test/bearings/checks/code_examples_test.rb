# frozen_string_literal: true

require 'test_helper'

describe Bearings::Checks::CodeExamples do
  def block(language, code)
    Bearings::Document::CodeBlock.new(language:, code:, line: 10)
  end

  def page(source_path, blocks)
    Bearings::Site::Page.new(
      title: 'Start',
      slug: 'start',
      description: nil,
      group_label: 'Start here',
      featured: false,
      num: '01',
      url: '/guides/start/',
      markdown_url: '/guides/start.md',
      canonical_url: nil,
      source_path:,
      edit_url: nil,
      previous_slug: nil,
      next_slug: nil,
      document: Bearings::Document.new(
        title: 'Start', headings: [], links: [], code_blocks: blocks, images: [], diagrams: [], body: ''
      ),
      extras: {}
    )
  end

  def site(pages)
    Bearings::Site.new(
      details: Bearings::Manifest::Site.new(
        name: 'Bearings', summary: nil, url: nil, repo: nil, version: nil, namespaces: []
      ),
      version: nil,
      groups: [],
      pages:
    )
  end

  def problems(*blocks)
    Bearings::Checks::CodeExamples.call(site([page('docs/START.md', blocks)]))
  end

  def problem(language, line, message)
    Bearings::Problem.new(
      check: 'code',
      level: :error,
      file: 'docs/START.md',
      line:,
      message: "the #{language} example does not parse: #{message}",
      hint: 'fix the example so it parses; show left-out code as a comment, not as `...`'
    )
  end

  describe '.call' do
    it "reports a failing block on each page against that page's source" do
      pages = [page('docs/START.md', [block('ruby', "foo(...)\n")]), page('docs/INSTALL.md', [block('json', '{')])]

      assert_equal %w[docs/START.md docs/INSTALL.md], Bearings::Checks::CodeExamples.call(site(pages)).map(&:file)
    end

    it 'reports nothing for a ruby block that parses' do
      assert_empty problems(block('ruby', "def greet(name)\n  puts \"hi \#{name}\"\nend\n"))
    end

    it "reports a ruby block that does not parse, with Prism's message" do
      assert_equal(
        [problem('ruby', 11, 'unexpected ... when the parent method is not forwarding')],
        problems(block('ruby', "foo(...)\n"))
      )
    end

    it 'reports the guide line where a ruby block fails to parse' do
      assert_equal [13], problems(block('ruby', "client = Client.new\nclient.connect\nclient.call(...)\n")).map(&:line)
    end

    it 'reports nothing for a json block that parses' do
      assert_empty problems(block('json', %({ "title": "Docs" }\n)))
    end

    it "reports a json block that does not parse, with the parser's message" do
      assert_equal [problem('json', 11, "expected object key, got: '}'")], problems(block('json', %({ "a": 1, }\n)))
    end

    it 'reports the guide line where a json block fails to parse' do
      assert_equal [13], problems(block('json', %({\n  "a": 1\n  "b": 2\n}\n))).map(&:line)
    end

    it "reports the block's first line when the json parser gives no line" do
      assert_equal [11], problems(block('json', "#{'[' * 200}#{']' * 200}\n")).map(&:line)
    end

    it 'reports nothing for a yaml block that parses' do
      assert_empty problems(block('yaml', "site:\n  name: Docs\n"))
    end

    it 'reports nothing for a yaml block that YAML.safe_load would refuse to load, such as one with an alias' do
      assert_empty problems(block('yaml', "default: &default\n  adapter: sqlite3\ndevelopment:\n  <<: *default\n"))
    end

    it "reports a yaml block that does not parse, with the parser's message" do
      assert_equal(
        [problem('yaml', 11, "did not find expected ',' or ']' while parsing a flow sequence")],
        problems(block('yaml', "pages: [start, install\n"))
      )
    end

    it 'reports the guide line where a yaml block fails to parse' do
      assert_equal [13], problems(block('yaml', "name: Docs\nurl: x\nrepo: a: b\n")).map(&:line)
    end

    it 'reports a yaml block whose later document does not parse' do
      assert_equal [14], problems(block('yaml', "a: 1\n---\nb: [\n")).map(&:line)
    end

    it 'skips a block in another language' do
      assert_empty problems(block('python', "def greet(:\n"))
    end
  end
end
