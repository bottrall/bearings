# frozen_string_literal: true

module Bearings::Checks::Diagrams
  extend self

  # @rbs!
  #   type finding = [:error | :warning, String, String]

  TYPES = %w[
    architecture-beta block block-beta C4Component C4Container C4Context C4Deployment C4Dynamic classDiagram
    classDiagram-v2 erDiagram flowchart flowchart-elk gantt gitGraph graph journey kanban mindmap packet
    packet-beta pie quadrantChart radar-beta requirement requirementDiagram sankey sankey-beta sequenceDiagram
    stateDiagram stateDiagram-v2 timeline treemap treemap-beta xychart xychart-beta zenuml
  ].to_set.freeze #: Set[String]
  FRONTMATTER = /\A---[ \t]*\n.*?^---[ \t]*$/m #: Regexp
  # Mermaid skips `%%` lines, comments and `%%{init: ...}%%` directives alike, so they may come before the type.
  TYPE = /^[ \t]*(?!%%)(\S+)/ #: Regexp
  ACC_TITLE = /^[ \t]*accTitle[ \t]*:/ #: Regexp
  EMPTY = [:error, 'has an empty diagram', 'write the diagram, or remove the fence'].freeze #: finding
  UNTYPED = [
    :error,
    'has a diagram whose first line names no Mermaid diagram type',
    'start the diagram with its type, such as `flowchart LR` or `sequenceDiagram`'
  ].freeze #: finding
  UNTITLED = [
    :warning,
    'has a diagram with no accTitle line, the alt text that describes it',
    'add an `accTitle: ...` line saying what the diagram shows'
  ].freeze #: finding

  # @rbs site: Bearings::Site
  # @rbs return: Array[Bearings::Problem]
  def call(site)
    site.pages.flat_map do |page|
      page.document.diagrams.flat_map { |diagram| problems(page.source_path, diagram) }
    end
  end

  private

  # @rbs file: String
  # @rbs diagram: Bearings::Document::Diagram
  # @rbs return: Array[Bearings::Problem]
  def problems(file, diagram)
    findings(diagram.code).map do |level, message, hint|
      Bearings::Problem.new(check: 'diagram', level:, file:, line: diagram.line, message:, hint:)
    end
  end

  # @rbs code: String
  # @rbs return: Array[finding]
  def findings(code)
    return [EMPTY] if code.strip.empty?

    [(UNTYPED unless typed?(code)), (UNTITLED unless ACC_TITLE.match?(code))].compact
  end

  # @rbs code: String
  # @rbs return: bool
  def typed?(code)
    TYPES.include?(code.sub(FRONTMATTER, '')[TYPE, 1].to_s)
  end
end
