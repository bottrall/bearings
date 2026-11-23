# frozen_string_literal: true

require 'psych'

module Bearings::Manifest::Parser
  extend self

  # @rbs!
  #   type issue = [Integer, String, String?]
  #   type kind = [String, ^(untyped) -> bool]
  #   type schema = Hash[String, kind?]
  #   type fields = Hash[String, Psych::Nodes::Node]

  LIST = ['a list', ->(value) { value.is_a?(Array) }].freeze #: kind
  TEXT = ['text', ->(value) { value.is_a?(String) }].freeze #: kind
  TEXTS = ['a list of text', ->(value) { value.is_a?(Array) && value.all?(String) }].freeze #: kind
  FLAG = ['true or false', ->(value) { [true, false].include?(value) }].freeze #: kind
  NUMBER = ['a whole number', ->(value) { value.is_a?(Integer) }].freeze #: kind
  PATHS = ['a mapping of path to path', ->(value) { value.is_a?(Hash) && [*value.keys, *value.values].all?(String) }].freeze #: kind

  MANIFEST = {
    'site' => nil, 'groups' => LIST, 'watch' => TEXTS, 'redirects' => PATHS, 'outputs' => nil, 'checks' => nil
  }.freeze #: schema
  SITE = {
    'name' => TEXT, 'summary' => TEXT, 'url' => TEXT, 'repo' => TEXT, 'version' => TEXT, 'namespaces' => TEXTS
  }.freeze #: schema
  OUTPUTS = { 'llms_full' => FLAG }.freeze #: schema
  CHECKS = { 'image_limit_kb' => NUMBER, 'external_links' => FLAG }.freeze #: schema
  GROUP = { 'label' => TEXT, 'pages' => LIST }.freeze #: schema
  PAGE = { 'source' => TEXT, 'slug' => TEXT, 'description' => TEXT, 'featured' => FLAG }.freeze #: schema

  SLUG = %r{\A[a-z0-9-]+(?:/[a-z0-9-]+)*\z}

  IMAGE_LIMIT_KB = 300

  # @rbs yaml: String
  # @rbs file: String
  # @rbs return: Bearings::Manifest | Array[Bearings::Problem]
  def parse(yaml, file:)
    document = Psych.parse(yaml)
    return problems([[1, 'the manifest is empty', nil]], file) unless document

    root = document.root
    unreadable = unreadable(root)
    issues = unreadable.empty? ? check(root) : unreadable
    issues.empty? ? build(root) : problems(issues, file)
  rescue Psych::SyntaxError => e
    problems([[e.line.to_i, "the manifest is not valid YAML: #{[e.problem, e.context].compact.join(' ')}", nil]], file)
  end

  private

  # @rbs issues: Array[issue]
  # @rbs file: String
  # @rbs return: Array[Bearings::Problem]
  def problems(issues, file)
    issues.map do |line, message, hint|
      Bearings::Problem.new(check: 'manifest', level: :error, file:, line:, message:, hint:)
    end
  end

  # @rbs node: Psych::Nodes::Node
  # @rbs return: Array[issue]
  def unreadable(node)
    value(node)
    []
  rescue Psych::Exception, ArgumentError
    inner = node.children.to_a.flat_map { |child| unreadable(child) }
    return inner unless inner.empty?

    [issue(
      node,
      'the manifest holds only text, numbers, true or false, lists and mappings',
      'Quote a date or a :symbol to make it text; YAML tags and aliases are not supported.'
    )]
  end

  # @rbs root: Psych::Nodes::Node
  # @rbs return: Array[issue]
  def check(root)
    top = fields(root)
    groups = items(top['groups'])
    pages = groups.flat_map { |group| items(fields(group)['pages']) }
    page_fields = pages.map { |page| fields(page) }
    [
      *check_mapping(root, 'the manifest', MANIFEST, required: %w[site groups]),
      *check_mapping(top['site'], '`site`', SITE, required: %w[name]),
      *check_mapping(top['outputs'], '`outputs`', OUTPUTS),
      *check_mapping(top['checks'], '`checks`', CHECKS),
      *groups.flat_map { |group| check_mapping(group, 'a group', GROUP, required: %w[label pages], open: true) },
      *pages.flat_map { |page| check_mapping(page, 'a page', PAGE, required: %w[source slug], open: true) },
      *unsafe_slugs(page_fields),
      *duplicates(page_fields, 'slug'),
      *duplicates(page_fields, 'source')
    ]
  end

  # @rbs node: Psych::Nodes::Node?
  # @rbs name: String
  # @rbs schema: schema
  # @rbs required: Array[String]
  # @rbs open: bool
  # @rbs return: Array[issue]
  def check_mapping(node, name, schema, required: [], open: false)
    return [] unless node
    return [issue(node, "#{name} must be a mapping")] unless node.is_a?(Psych::Nodes::Mapping)

    fields = fields(node)
    missing = (required - fields.keys).map { |key| issue(node, "#{name} is missing `#{key}`") }
    unknown = pairs(node).map(&:first).reject { |key| open || schema.key?(value(key).to_s) }.map do |key|
      issue(key, "#{name} has an unknown key `#{value(key)}`", "Known keys: #{schema.keys.join(', ')}.")
    end
    mistyped = fields.filter_map do |key, field|
      description, test = schema[key]
      issue(field, "`#{key}` must be #{description}") if test && !test.call(value(field))
    end
    missing + unknown + mistyped
  end

  # @rbs pages: Array[fields]
  # @rbs return: Array[issue]
  def unsafe_slugs(pages)
    pages.filter_map { |page| page['slug'] }
         .reject { |slug| SLUG.match?(value(slug).to_s) }
         .map do |slug|
           issue(
             slug,
             "slug `#{value(slug)}` is not URL-safe",
             'Use lowercase letters, digits and hyphens, with / between segments.'
           )
         end
  end

  # @rbs pages: Array[fields]
  # @rbs key: String
  # @rbs return: Array[issue]
  def duplicates(pages, key)
    pages.filter_map { |page| page[key] }
         .group_by { |node| value(node) }
         .values
         .flat_map do |nodes|
           first = nodes.fetch(0)
           nodes.drop(1).map do |node|
             issue(node, "duplicate #{key} `#{value(node)}`, first used on line #{line(first)}")
           end
         end
  end

  # @rbs root: Psych::Nodes::Node
  # @rbs return: Bearings::Manifest
  def build(root)
    top = fields(root)
    site = fields(top['site'])
    outputs = fields(top['outputs'])
    checks = fields(top['checks'])
    Bearings::Manifest.new(
      site: Bearings::Manifest::Site.new(
        name: value(site['name']),
        summary: value(site['summary']),
        url: value(site['url']),
        repo: value(site['repo']),
        version: value(site['version']),
        namespaces: value(site['namespaces']) || []
      ),
      groups: items(top['groups']).map { |group| build_group(group) },
      watch: value(top['watch']) || [],
      redirects: build_redirects(top['redirects']),
      outputs: Bearings::Manifest::Outputs.new(llms_full: value(outputs['llms_full']) || false),
      checks: Bearings::Manifest::Checks.new(
        image_limit_kb: value(checks['image_limit_kb']) || IMAGE_LIMIT_KB,
        external_links: value(checks['external_links']) || false
      )
    )
  end

  # @rbs node: Psych::Nodes::Node
  # @rbs return: Bearings::Manifest::Group
  def build_group(node)
    group = fields(node)
    Bearings::Manifest::Group.new(
      label: value(group['label']),
      pages: items(group['pages']).map { |page| build_page(page) },
      extras: extras(node, GROUP)
    )
  end

  # @rbs node: Psych::Nodes::Node
  # @rbs return: Bearings::Manifest::Page
  def build_page(node)
    page = fields(node)
    Bearings::Manifest::Page.new(
      source: value(page['source']),
      slug: value(page['slug']),
      description: value(page['description']),
      featured: value(page['featured']) || false,
      extras: extras(node, PAGE)
    )
  end

  # @rbs node: Psych::Nodes::Node?
  # @rbs return: Array[Bearings::Manifest::Redirect]
  def build_redirects(node)
    return [] unless node.is_a?(Psych::Nodes::Mapping)

    pairs(node).map { |from, to| Bearings::Manifest::Redirect.new(from: value(from), to: value(to), line: line(from)) }
  end

  # @rbs node: Psych::Nodes::Node
  # @rbs schema: schema
  # @rbs return: Hash[String, untyped]
  def extras(node, schema)
    entries(node).except(*schema.keys).transform_values { |field| value(field) }
  end

  # @rbs node: Psych::Nodes::Node?
  # @rbs return: fields
  def fields(node)
    entries(node).reject { |_, field| field.is_a?(Psych::Nodes::Scalar) && value(field).nil? }
  end

  # @rbs node: Psych::Nodes::Node?
  # @rbs return: fields
  def entries(node)
    return {} unless node.is_a?(Psych::Nodes::Mapping)

    pairs(node).to_h { |key, field| [value(key).to_s, field] }
  end

  # @rbs mapping: Psych::Nodes::Mapping
  # @rbs return: Array[[Psych::Nodes::Node, Psych::Nodes::Node]]
  def pairs(mapping)
    mapping.children.each_slice(2).to_a #: Array[[Psych::Nodes::Node, Psych::Nodes::Node]]
  end

  # @rbs node: Psych::Nodes::Node?
  # @rbs return: Array[Psych::Nodes::Node]
  def items(node)
    node.is_a?(Psych::Nodes::Sequence) ? node.children : []
  end

  # @rbs node: Psych::Nodes::Node?
  # @rbs return: untyped
  def value(node)
    return unless node

    # The same visitor Psych.safe_load uses, so the manifest can never build an arbitrary Ruby object.
    loader = Psych::ClassLoader::Restricted.new([], [])
    Psych::Visitors::NoAliasRuby.new(Psych::ScalarScanner.new(loader), loader).accept(node)
  end

  # @rbs node: Psych::Nodes::Node
  # @rbs message: String
  # @rbs hint: String?
  # @rbs return: issue
  def issue(node, message, hint = nil)
    [line(node), message, hint]
  end

  # @rbs node: Psych::Nodes::Node
  # @rbs return: Integer
  def line(node)
    node.start_line + 1
  end
end
