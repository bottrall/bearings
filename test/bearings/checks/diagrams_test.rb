# frozen_string_literal: true

require 'test_helper'

describe Bearings::Checks::Diagrams do
  def diagram(code)
    Bearings::Document::Diagram.new(code:, line: 10)
  end

  def page(source_path, diagrams)
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
        title: 'Start', headings: [], links: [], code_blocks: [], code_spans: [], images: [], diagrams:, body: ''
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

  def problems(code)
    Bearings::Checks::Diagrams.call(site([page('docs/START.md', [diagram(code)])]))
  end

  def messages(code) = problems(code).map(&:message)

  def untyped = 'has a diagram whose first line names no Mermaid diagram type'

  def problem(level, message, hint)
    Bearings::Problem.new(check: 'diagram', level:, file: 'docs/START.md', line: 10, message:, hint:)
  end

  describe '.call' do
    it "reports a diagram on each page against that page's source" do
      pages = [page('docs/START.md', [diagram('')]), page('docs/INSTALL.md', [diagram('')])]

      assert_equal %w[docs/START.md docs/INSTALL.md], Bearings::Checks::Diagrams.call(site(pages)).map(&:file)
    end

    it "reports an empty diagram as an error at the diagram's line" do
      assert_equal([problem(:error, 'has an empty diagram', 'write the diagram, or remove the fence')], problems(''))
    end

    it 'reports a diagram of only blank lines as empty' do
      assert_equal ['has an empty diagram'], messages("\n  \n")
    end

    it 'reports nothing for a titled diagram whose first line names its type' do
      assert_empty problems("flowchart LR\n  accTitle: The build\n  a --> b\n")
    end

    it "reports a diagram whose first line names no Mermaid diagram type as an error at the diagram's line" do
      assert_equal(
        [problem(:error, untyped, 'start the diagram with its type, such as `flowchart LR` or `sequenceDiagram`')],
        problems("a --> b\naccTitle: The build\n")
      )
    end

    it 'reports a first line that only starts with the name of a diagram type' do
      assert_equal [untyped], messages("flowcharts LR\naccTitle: The build\n")
    end

    it 'reads the type from the first line after the frontmatter' do
      assert_empty problems("---\ntitle: The build\n---\nsequenceDiagram\naccTitle: The build\n")
    end

    it 'reads the type from the first line after blank lines, comments and directives' do
      assert_empty problems("\n%% The build\n  %%{init: {'theme': 'dark'}}%%\ngraph TD\naccTitle: The build\n")
    end

    it 'reports a diagram of only comments as naming no type' do
      assert_includes messages("%% The build\n"), untyped
    end

    it "warns about a diagram with no accTitle line, at the diagram's line" do
      assert_equal(
        [problem(
          :warning,
          'has a diagram with no accTitle line, the alt text that describes it',
          'add an `accTitle: ...` line saying what the diagram shows'
        )],
        problems("graph TD\n  a --> b\n")
      )
    end
  end
end
