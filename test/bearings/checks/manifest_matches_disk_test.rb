# frozen_string_literal: true

require 'test_helper'

describe Bearings::Checks::ManifestMatchesDisk do
  def listed(source, description: 'What it covers')
    Bearings::Manifest::Page.new(source:, slug: 'guide', description:, featured: false, extras: {})
  end

  def manifest(pages: [listed('docs/START.md')], watch: ['docs'])
    Bearings::Manifest.new(
      site: Bearings::Manifest::Site.new(
        name: 'Bearings',
        summary: nil,
        url: nil,
        repo: nil,
        version: nil,
        namespaces: []
      ),
      groups: [Bearings::Manifest::Group.new(label: 'Start here', pages:, extras: {})],
      watch:,
      redirects: {},
      outputs: Bearings::Manifest::Outputs.new(llms_full: false),
      checks: Bearings::Manifest::Checks.new(image_limit_kb: 300)
    )
  end

  def check(paths, **)
    Bearings::Checks::ManifestMatchesDisk.call(manifest: manifest(**), paths:)
  end

  describe '.call' do
    it 'reports an unlisted file under a watch folder written with a trailing slash' do
      assert_equal ['docs/OLD.md'], check(['docs/START.md', 'docs/OLD.md'], watch: ['docs/']).map(&:file)
    end

    it 'leaves a listed file that is missing to the site model' do
      assert_empty check([])
    end

    it 'ignores a file that is not markdown' do
      assert_empty check(['docs/START.md', 'docs/diagram.png'])
    end

    it 'ignores markdown outside the watched folders' do
      assert_empty check(['docs/START.md', 'README.md'])
    end

    it 'ignores a folder whose name only starts with a watched one' do
      assert_empty check(['docs/START.md', 'docs-old/START.md'])
    end

    it 'reports an unlisted file in a folder nested under a watched one' do
      assert_equal ['docs/reference/OLD.md'], check(['docs/START.md', 'docs/reference/OLD.md']).map(&:file)
    end

    it 'reports unlisted files under each watched folder' do
      assert_equal %w[docs/OLD.md guides/OLD.md],
                   check(['docs/START.md', 'docs/OLD.md', 'guides/OLD.md'], watch: %w[docs guides]).map(&:file)
    end

    it 'ignores every file when no folder is watched' do
      assert_empty check(['docs/START.md', 'docs/OLD.md'], watch: [])
    end

    it 'reports a markdown file in a watched folder that no page lists' do
      unlisted = Bearings::Problem.new(
        check: 'unlisted',
        level: :error,
        file: 'docs/OLD.md',
        line: 1,
        message: 'is in a watched folder but no page in the manifest lists it',
        hint: 'add a page with this `source` to the manifest, or move the file out of the watched folder'
      )

      assert_equal [unlisted], check(['docs/START.md', 'docs/OLD.md'])
    end

    it 'reports a page with no description' do
      undescribed = Bearings::Problem.new(
        check: 'description',
        level: :error,
        file: 'docs/START.md',
        line: 1,
        message: 'has no description in the manifest',
        hint: 'add a one-line `description` to its page in the manifest'
      )

      assert_equal [undescribed], check(['docs/START.md'], pages: [listed('docs/START.md', description: nil)])
    end

    it 'reports a page whose description is only whitespace' do
      assert_equal ['docs/START.md'],
                   check(['docs/START.md'], pages: [listed('docs/START.md', description: " \n")]).map(&:file)
    end

    it 'passes a manifest that lists every watched guide and describes every page' do
      assert_empty check(['docs/START.md'])
    end

    it 'reports every mismatch, not only the first' do
      assert_equal %w[docs/OLD.md docs/NEW.md docs/START.md],
                   check(
                     ['docs/START.md', 'docs/OLD.md', 'docs/NEW.md'],
                     pages: [listed('docs/START.md', description: nil)]
                   ).map(&:file)
    end
  end
end
