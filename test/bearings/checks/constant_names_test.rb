# frozen_string_literal: true

require 'test_helper'

describe Bearings::Checks::ConstantNames do
  def declared = Set['Riffer', 'Riffer::Agent', 'Riffer::Providers::Anthropic']

  def block(code, language: 'ruby', line: 10) = Bearings::Document::CodeBlock.new(language:, code:, line:)

  def span(code, line: 5) = Bearings::Document::CodeSpan.new(code:, line:)

  def page(source_path, code_blocks: [], code_spans: [])
    document = Bearings::Document.new(
      title: 'Agents', headings: [], links: [], code_blocks:, code_spans:, images: [], diagrams: [], body: ''
    )
    Bearings::Site::Page.new(
      title: 'Agents',
      slug: 'agents',
      description: nil,
      group_label: 'Guides',
      featured: false,
      num: '01',
      url: '/guides/agents/',
      markdown_url: '/guides/agents.md',
      canonical_url: nil,
      source_path:,
      edit_url: nil,
      previous_slug: nil,
      next_slug: nil,
      document:,
      extras: {}
    )
  end

  def site(pages, namespaces)
    Bearings::Site.new(
      details: Bearings::Manifest::Site.new(
        name: 'Riffer', summary: nil, url: nil, repo: nil, version: nil, namespaces:
      ),
      version: nil,
      groups: [],
      pages:
    )
  end

  def problems(*pages, namespaces: ['Riffer'])
    Bearings::Checks::ConstantNames.call(site: site(pages, namespaces), declared:)
  end

  def check(namespaces: ['Riffer'], **document) = problems(page('docs/AGENTS.md', **document), namespaces:)

  def names(...) = check(...).map { |problem| problem.message[/`([^`]+)`/, 1] }

  def lines(...) = check(...).map(&:line)

  describe '.call' do
    it 'reports an undeclared constant in a ruby block, on the page, with the closest declared name' do
      assert_equal(
        [
          Bearings::Problem.new(
            check: 'constant',
            level: :error,
            file: 'docs/AGENTS.md',
            line: 11,
            message: 'names `Riffer::Agnt`, which the RBS signatures do not declare',
            hint: 'did you mean `Riffer::Agent`?'
          )
        ],
        check(code_blocks: [block("agent = Riffer::Agnt.new\n")])
      )
    end

    it 'gives a constant in a block the line it has in the guide' do
      assert_equal [12], lines(code_blocks: [block("agent = nil\nRiffer::Missing.new\n")])
    end

    it 'passes a declared constant in a block' do
      assert_empty check(code_blocks: [block("Riffer::Agent.new\n")])
    end

    it 'leaves out a block in another language' do
      assert_empty check(code_blocks: [block(%({ "class": "Riffer::Missing" }\n), language: 'json')])
    end

    it 'reports the constants in a block that does not parse' do
      assert_equal ['Riffer::Missing'], names(code_blocks: [block("Riffer::Missing.new(\n")])
    end

    it 'reports an undeclared constant in a code span on the span line' do
      assert_equal [5], lines(code_spans: [span('Riffer::Missing')])
    end

    it 'passes a declared constant in a code span' do
      assert_empty check(code_spans: [span('Riffer::Providers::Anthropic')])
    end

    it 'checks only the constant of a code span that names a method' do
      assert_equal ['Riffer::Missing'], names(code_spans: [span('Riffer::Missing#generate')])
    end

    it 'gives a constant on a later line of a code span that line' do
      assert_equal [6], lines(code_spans: [span("agent =\nRiffer::Missing.new")])
    end

    it 'reports a constant named twice on one line once' do
      assert_equal 1, check(code_blocks: [block("Riffer::Missing.new(Riffer::Missing)\n")]).size
    end

    it 'checks a configured namespace itself' do
      assert_equal ['Rig'], names(code_spans: [span('Rig')], namespaces: ['Rig'])
    end

    it 'leaves out a constant in a namespace that is not configured' do
      assert_empty check(code_spans: [span('Other::Missing')])
    end

    it 'leaves out a constant whose first segment only starts with a namespace' do
      assert_empty check(code_spans: [span('RifferRig::Missing')])
    end

    it 'passes a class a block on the page defines' do
      assert_empty check(code_blocks: [block("class Riffer::Custom\nend\n")], code_spans: [span('Riffer::Custom')])
    end

    it 'passes a class defined inside a module by its full name' do
      code = "module Riffer\n  class Custom\n  end\nend\n"

      assert_empty check(code_blocks: [block(code)], code_spans: [span('Riffer::Custom')])
    end

    it 'passes a constant assigned inside a module by its full name' do
      code = "module Riffer\n  LIMIT = 1\nend\n"

      assert_empty check(code_blocks: [block(code)], code_spans: [span('Riffer::LIMIT')])
    end

    it 'passes a constant assigned by its path' do
      assert_empty check(code_blocks: [block("Riffer::Custom = Class.new\n")], code_spans: [span('Riffer::Custom')])
    end

    it 'passes a class defined from the top level inside another module' do
      code = "module Other\n  class ::Riffer::Custom\n  end\nend\n"

      assert_empty check(code_blocks: [block(code)], code_spans: [span('Riffer::Custom')])
    end

    it 'passes a class defined in a code span only when a block defines it' do
      assert_equal ['Riffer::Custom'], names(code_spans: [span('class Riffer::Custom; end')])
    end

    it 'reports a name another page defines' do
      defines = page('docs/CUSTOM.md', code_blocks: [block("class Riffer::Custom\nend\n")])
      names = page('docs/AGENTS.md', code_spans: [span('Riffer::Custom')])

      assert_equal ['docs/AGENTS.md'], problems(defines, names).map(&:file)
    end

    it 'checks a constant written from the top level without its leading ::' do
      assert_empty check(code_spans: [span('::Riffer::Agent')])
    end

    it 'checks the constant a method call is made on, not one reached through it' do
      assert_empty check(code_spans: [span('Riffer.config::Missing')])
    end

    it 'checks the constant before a path the parser could not finish' do
      assert_empty check(code_spans: [span('Riffer::')])
    end

    it 'hints at fixing or declaring a name when no declared name is close' do
      assert_equal ['fix the name, or declare the constant in sig/'],
                   check(code_spans: [span('Rig::Toolkit')], namespaces: ['Rig']).map(&:hint)
    end
  end
end
