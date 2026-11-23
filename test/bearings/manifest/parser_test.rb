# frozen_string_literal: true

require 'test_helper'

describe Bearings::Manifest::Parser do
  def parse(yaml)
    Bearings::Manifest::Parser.parse(yaml, file: 'docs-site/manifest.yml')
  end

  def problems(yaml)
    parse(yaml).map { |problem| [problem.line, problem.message] }
  end

  def full
    <<~YAML
      site:
        name: Bearings
        summary: A themeless docs engine
        url: https://bearings.example
        repo: https://github.com/bottrall/bearings
        version: lib/bearings/version.rb
        namespaces: [Bearings]
      groups:
        - label: Start here
          tone: teal
          pages:
            - source: docs/START.md
              slug: start
              description: Install it and build a site
              featured: true
              badge: new
        - label: Reference
          pages:
            - source: docs/reference/MANIFEST.md
              slug: reference/manifest
              description: Every manifest key
      watch: [docs]
      redirects:
        /old/: /guides/start/
      outputs:
        llms_full: true
      checks:
        image_limit_kb: 200
        external_links: true
    YAML
  end

  def full_manifest
    Bearings::Manifest.new(
      site: Bearings::Manifest::Site.new(
        name: 'Bearings',
        summary: 'A themeless docs engine',
        url: 'https://bearings.example',
        repo: 'https://github.com/bottrall/bearings',
        version: 'lib/bearings/version.rb',
        namespaces: ['Bearings']
      ),
      groups: [
        Bearings::Manifest::Group.new(
          label: 'Start here',
          pages: [page(description: 'Install it and build a site', featured: true, extras: { 'badge' => 'new' })],
          extras: { 'tone' => 'teal' }
        ),
        Bearings::Manifest::Group.new(
          label: 'Reference',
          pages: [page(
            source: 'docs/reference/MANIFEST.md',
            slug: 'reference/manifest',
            description: 'Every manifest key'
          )],
          extras: {}
        )
      ],
      watch: ['docs'],
      redirects: [Bearings::Manifest::Redirect.new(from: '/old/', to: '/guides/start/', line: 24)],
      outputs: Bearings::Manifest::Outputs.new(llms_full: true),
      checks: Bearings::Manifest::Checks.new(image_limit_kb: 200, external_links: true)
    )
  end

  def minimal
    <<~YAML
      site:
        name: Bearings
      groups:
        - label: Start here
          pages:
            - source: docs/START.md
              slug: start
    YAML
  end

  def minimal_manifest
    Bearings::Manifest.new(
      site: Bearings::Manifest::Site.new(
        name: 'Bearings',
        summary: nil,
        url: nil,
        repo: nil,
        version: nil,
        namespaces: []
      ),
      groups: [Bearings::Manifest::Group.new(label: 'Start here', pages: [page], extras: {})],
      watch: [],
      redirects: [],
      outputs: Bearings::Manifest::Outputs.new(llms_full: false),
      checks: Bearings::Manifest::Checks.new(image_limit_kb: 300, external_links: false)
    )
  end

  def page(**fields)
    Bearings::Manifest::Page.new(
      source: 'docs/START.md',
      slug: 'start',
      description: nil,
      featured: false,
      extras: {},
      **fields
    )
  end

  describe '.parse' do
    it 'reports YAML that does not parse, with its line' do
      assert_equal [[3, 'the manifest is not valid YAML: mapping values are not allowed in this context']],
                   problems("site:\n  name: Bearings\n  summary: docs: plain\n")
    end

    it 'reports an empty manifest' do
      assert_equal [[1, 'the manifest is empty']], problems('')
    end

    it 'reports each problem as a manifest error in the given file' do
      assert_equal(
        [%w[manifest error docs-site/manifest.yml]],
        parse('').map { |problem| [problem.check, problem.level.to_s, problem.file] }
      )
    end

    it 'reports a value that would load as a Ruby object at its line' do
      assert_equal [[3, 'the manifest holds only text, numbers, true or false, lists and mappings']],
                   problems("site:\n  name: Bearings\n  released: 2026-01-01\n")
    end

    it 'reports a value Psych cannot convert' do
      assert_equal [[2, 'the manifest holds only text, numbers, true or false, lists and mappings']],
                   problems("site:\n  name: !!float Bearings\n")
    end

    it 'reports a YAML alias' do
      assert_equal [[3, 'the manifest holds only text, numbers, true or false, lists and mappings']],
                   problems("site: &site\n  name: Bearings\nother: *site\n")
    end

    it 'reports a tagged mapping as a whole' do
      assert_equal [[1, 'the manifest holds only text, numbers, true or false, lists and mappings']],
                   problems("site: !ruby/object:Bearings::Manifest::Site\n  name: Bearings\n")
    end

    it 'hints at quoting a value it cannot read' do
      assert_equal 'Quote a date or a :symbol to make it text; YAML tags and aliases are not supported.',
                   parse("site:\n  released: 2026-01-01\n").first.hint
    end

    it 'reports a manifest that is not a mapping' do
      assert_equal [[1, 'the manifest must be a mapping']], problems("- site\n- groups\n")
    end

    it 'reports a missing top-level key at the start of the manifest' do
      assert_equal [[1, 'the manifest is missing `groups`']], problems("site:\n  name: Bearings\n")
    end

    it 'treats a key with no value as missing' do
      assert_equal [[1, 'the manifest is missing `groups`']], problems("site:\n  name: Bearings\ngroups:\n")
    end

    it 'reports an unknown top-level key at its line' do
      assert_equal [[3, 'the manifest has an unknown key `theme`']],
                   problems("site:\n  name: Bearings\ntheme: dark\ngroups: []\n")
    end

    it 'hints at the known keys for an unknown one' do
      assert_equal 'Known keys: site, groups, watch, redirects, outputs, checks.',
                   parse("site:\n  name: Bearings\ntheme: dark\ngroups: []\n").first.hint
    end

    it 'reports a top-level value of the wrong type' do
      assert_equal [[3, '`groups` must be a list']], problems("site:\n  name: Bearings\ngroups: Start here\n")
    end

    it 'reports redirects that are not a mapping of path to path' do
      assert_equal [[5, '`redirects` must be a mapping of path to path']],
                   problems("site:\n  name: Bearings\ngroups: []\nredirects:\n  /old/: [/new/]\n")
    end

    it 'reports a site that is not a mapping' do
      assert_equal [[1, '`site` must be a mapping']], problems("site: Bearings\ngroups: []\n")
    end

    it 'reports a site with no name at the start of the site' do
      assert_equal [[2, '`site` is missing `name`']], problems("site:\n  url: https://bearings.example\ngroups: []\n")
    end

    it 'reports an unknown site key' do
      assert_equal [[3, '`site` has an unknown key `title`']],
                   problems("site:\n  name: Bearings\n  title: Bearings\ngroups: []\n")
    end

    it 'reports a site value that is not text' do
      assert_equal [[2, '`name` must be text']], problems("site:\n  name: 42\ngroups: []\n")
    end

    it 'reports a site value of the wrong type' do
      assert_equal [[2, '`namespaces` must be a list of text']],
                   problems("site:\n  namespaces: Bearings\n  name: Bearings\ngroups: []\n")
    end

    it 'reports an output of the wrong type' do
      assert_equal [[5, '`llms_full` must be true or false']],
                   problems("site:\n  name: Bearings\ngroups: []\noutputs:\n  llms_full: sometimes\n")
    end

    it 'reports an unknown check' do
      assert_equal [[5, '`checks` has an unknown key `spelling`']],
                   problems("site:\n  name: Bearings\ngroups: []\nchecks:\n  spelling: true\n")
    end

    it 'reports a check of the wrong type' do
      assert_equal [[5, '`image_limit_kb` must be a whole number']],
                   problems("site:\n  name: Bearings\ngroups: []\nchecks:\n  image_limit_kb: large\n")
    end

    it 'reports a group that is not a mapping' do
      assert_equal [[4, 'a group must be a mapping']], problems("site:\n  name: Bearings\ngroups:\n  - Start here\n")
    end

    it 'reports a group with no label at the start of the group' do
      assert_equal [[4, 'a group is missing `label`']], problems("site:\n  name: Bearings\ngroups:\n  - pages: []\n")
    end

    it 'reports a page with no slug at the start of the page' do
      assert_equal [[6, 'a page is missing `slug`']], problems(<<~YAML)
        site:
          name: Bearings
        groups:
          - label: Start here
            pages:
              - source: docs/START.md
                description: Install it
      YAML
    end

    it 'reports a page value of the wrong type' do
      assert_equal [[8, '`featured` must be true or false']], problems(<<~YAML)
        site:
          name: Bearings
        groups:
          - label: Start here
            pages:
              - source: docs/START.md
                slug: start
                featured: maybe
      YAML
    end

    it 'reports a slug that is not URL-safe at its line' do
      assert_equal [[7, 'slug `Getting Started` is not URL-safe']], problems(<<~YAML)
        site:
          name: Bearings
        groups:
          - label: Start here
            pages:
              - source: docs/START.md
                slug: Getting Started
      YAML
    end

    it 'hints at the slug rule' do
      assert_equal 'Use lowercase letters, digits and hyphens, with / between segments.', parse(<<~YAML).first.hint
        site:
          name: Bearings
        groups:
          - label: Start here
            pages:
              - source: docs/START.md
                slug: getting_started
      YAML
    end

    it 'reports a duplicate slug at its second use, across groups' do
      assert_equal [[11, 'duplicate slug `start`, first used on line 7']], problems(<<~YAML)
        site:
          name: Bearings
        groups:
          - label: Start here
            pages:
              - source: docs/START.md
                slug: start
          - label: Reference
            pages:
              - source: docs/reference/START.md
                slug: start
      YAML
    end

    it 'reports a duplicate source at its second use' do
      assert_equal [[8, 'duplicate source `docs/START.md`, first used on line 6']], problems(<<~YAML)
        site:
          name: Bearings
        groups:
          - label: Start here
            pages:
              - source: docs/START.md
                slug: start
              - source: docs/START.md
                slug: start-again
      YAML
    end

    it 'loads a full manifest' do
      assert_equal full_manifest, parse(full)
    end

    it 'fills in the defaults for every optional key' do
      assert_equal minimal_manifest, parse(minimal)
    end

    it 'keeps unknown group keys for the layout' do
      assert_equal({ 'tone' => 'teal' }, parse(full).groups.first.extras)
    end

    it 'keeps unknown page keys for the layout' do
      assert_equal({ 'badge' => 'new' }, parse(full).groups.first.pages.first.extras)
    end

    it 'keeps an unknown page key that has no value' do
      assert_equal({ 'badge' => nil }, parse("#{minimal}        badge:\n").groups.first.pages.first.extras)
    end

    it 'loads each redirect in order, with the line of its old path' do
      assert_equal(
        [
          Bearings::Manifest::Redirect.new(from: '/old/', to: '/guides/start/', line: 9),
          Bearings::Manifest::Redirect.new(from: '/api/', to: '/guides/reference/manifest/', line: 10)
        ],
        parse("#{minimal}redirects:\n  /old/: /guides/start/\n  /api/: /guides/reference/manifest/\n").redirects
      )
    end

    it "loads riffer-rig's manifest with a site block added" do
      assert_instance_of Bearings::Manifest, parse(File.read('test/fixtures/manifest/riffer-rig.yml'))
    end
  end
end
