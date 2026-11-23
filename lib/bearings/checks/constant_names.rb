# frozen_string_literal: true

require 'did_you_mean'
require 'prism'

module Bearings::Checks::ConstantNames
  extend self

  # @rbs!
  #   type reference = [String, Integer]
  #   type snippet = [Prism::ProgramNode, Integer]

  CONSTANT_PATH = /\A(?:::)?[A-Z]\w*(?:::[A-Z]\w*)*\z/ #: Regexp

  # @rbs site: Bearings::Site
  # @rbs declared: Set[String]
  # @rbs return: Array[Bearings::Problem]
  def call(site:, declared:)
    spell_checker = DidYouMean::SpellChecker.new(dictionary: declared.to_a)
    site.pages.flat_map do |page|
      undeclared(page.document, site.details.namespaces, declared).map do |name, line|
        problem(page.source_path, name, line, spell_checker.correct(name).first)
      end
    end
  end

  private

  # @rbs document: Bearings::Document
  # @rbs namespaces: Array[String]
  # @rbs declared: Set[String]
  # @rbs return: Array[reference]
  def undeclared(document, namespaces, declared)
    blocks = document.code_blocks.select { |block| block.language == 'ruby' }
    examples = blocks.map { |block| [Prism.parse(block.code).value, block.line + 1] } #: Array[snippet]
    spans = document.code_spans.map { |span| [Prism.parse(span.code).value, span.line] } #: Array[snippet]
    known = declared + examples.flat_map { |tree, _| definitions(tree, nil) }
    scopes = namespaces.map { |namespace| "#{namespace}::" }
    [*examples, *spans].flat_map { |tree, first_line| references(tree, first_line) }.uniq.select do |name, _|
      "#{name}::".start_with?(*scopes) && !known.include?(name)
    end
  end

  # @rbs node: Prism::node
  # @rbs scope: String?
  # @rbs return: Array[String]
  def definitions(node, scope)
    name = defined_name(node, scope)
    inner = node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode) ? name : scope
    [name, *node.compact_child_nodes.flat_map { |child| definitions(child, inner) }].compact
  end

  # @rbs node: Prism::node
  # @rbs scope: String?
  # @rbs return: String?
  def defined_name(node, scope)
    written = case node
              when Prism::ClassNode, Prism::ModuleNode then path(node.constant_path)
              when Prism::ConstantPathWriteNode then path(node.target)
              when Prism::ConstantWriteNode then node.name.to_s
              end
    return unless written

    written.start_with?('::') ? written.delete_prefix('::') : [scope, written].compact.join('::')
  end

  # @rbs node: Prism::node
  # @rbs first_line: Integer
  # @rbs return: Array[reference]
  def references(node, first_line)
    name = path(node) if node.is_a?(Prism::ConstantReadNode) || node.is_a?(Prism::ConstantPathNode)
    return [[name.delete_prefix('::'), first_line + node.location.start_line - 1]] if name

    node.compact_child_nodes.flat_map { |child| references(child, first_line) }
  end

  # @rbs node: Prism::node
  # @rbs return: String?
  def path(node)
    # A path with a dynamic part (`config::Agent`) or one the parser recovered (`Riffer::`) is not a name.
    node.slice[CONSTANT_PATH]
  end

  # @rbs file: String
  # @rbs name: String
  # @rbs line: Integer
  # @rbs closest: String?
  # @rbs return: Bearings::Problem
  def problem(file, name, line, closest)
    Bearings::Problem.new(
      check: 'constant',
      level: :error,
      file:,
      line:,
      message: "names `#{name}`, which the RBS signatures do not declare",
      hint: closest ? "did you mean `#{closest}`?" : 'fix the name, or declare the constant in sig/'
    )
  end
end
