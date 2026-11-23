# frozen_string_literal: true

Bearings::Site = Data.define(:details, :version, :groups, :pages)

# Reopened because rbs-inline reads nothing in a block given to `Data.define` on a compact constant.
class Bearings::Site
  ASSIGNED_VERSION = /\bVERSION\s*=\s*['"]([^'"]+)['"]/ #: Regexp

  class << self
    # @rbs manifest: Bearings::Manifest
    # @rbs files: Hash[String, String]
    # @rbs markdown: Bearings::_Markdown
    # @rbs return: [Bearings::Site, Array[Bearings::Problem]]
    def build(manifest:, files:, markdown:)
      version = read_version(manifest.site.version, files)
      numbers = chapter_numbers(manifest.groups.flat_map(&:pages).map(&:source))
      built = manifest.groups.flat_map do |group|
        group.pages.map do |entry|
          page(entry, group.label, numbers.fetch(entry.source), manifest.site, files, markdown)
        end
      end
      found = built.grep(Bearings::Site::Page) #: Array[Bearings::Site::Page]
      pages = linked(found)
      problems = [version, *built].grep(Bearings::Problem) #: Array[Bearings::Problem]
      site = new(
        details: manifest.site,
        version: (version if version.is_a?(String)),
        groups: groups(manifest.groups, pages),
        pages:
      )
      [site, problems]
    end

    private

    # @rbs path: String?
    # @rbs files: Hash[String, String]
    # @rbs return: String | Bearings::Problem | nil
    def read_version(path, files)
      return unless path

      files.fetch(path, '')[ASSIGNED_VERSION, 1] || Bearings::Problem.new(
        check: 'version',
        level: :error,
        file: path,
        line: 1,
        message: 'has no version',
        hint: "set VERSION = '…' in it, or point `site.version` at the file that does"
      )
    end

    # @rbs sources: Array[String]
    # @rbs return: Hash[String, String]
    def chapter_numbers(sources)
      sources.group_by { |source| File.dirname(source) }.values.flat_map do |folder|
        folder.map.with_index(1) { |source, number| [source, format('%02d', number)] }
      end.to_h
    end

    # @rbs entry: Bearings::Manifest::Page
    # @rbs label: String
    # @rbs num: String
    # @rbs site: Bearings::Manifest::Site
    # @rbs files: Hash[String, String]
    # @rbs markdown: Bearings::_Markdown
    # @rbs return: Bearings::Site::Page | Bearings::Problem
    def page(entry, label, num, site, files, markdown)
      source = files.fetch(entry.source, nil)
      return missing(entry.source) unless source

      document = Bearings::Guide.parse(entry.source, source, markdown)
      return document if document.is_a?(Bearings::Problem)

      Bearings::Site::Page.new(
        title: document.title,
        slug: entry.slug,
        description: entry.description,
        group_label: label,
        featured: entry.featured,
        num:,
        url: "/guides/#{entry.slug}/",
        markdown_url: "/guides/#{entry.slug}.md",
        canonical_url: under(site.url, "guides/#{entry.slug}/"),
        source_path: entry.source,
        edit_url: under(site.repo, "edit/main/#{entry.source}"),
        previous_slug: nil,
        next_slug: nil,
        document:,
        extras: entry.extras
      )
    end

    # @rbs source: String
    # @rbs return: Bearings::Problem
    def missing(source)
      Bearings::Problem.new(
        check: 'source',
        level: :error,
        file: source,
        line: 1,
        message: 'is listed in the manifest but was not found',
        hint: 'add the file, or remove its page from the manifest'
      )
    end

    # @rbs base: String?
    # @rbs path: String
    # @rbs return: String?
    def under(base, path)
      "#{base.delete_suffix('/')}/#{path}" if base
    end

    # @rbs pages: Array[Bearings::Site::Page]
    # @rbs return: Array[Bearings::Site::Page]
    def linked(pages)
      pages.zip([nil, *pages], pages.drop(1)).map do |page, previous, following|
        page.with(previous_slug: previous&.slug, next_slug: following&.slug)
      end
    end

    # @rbs listed: Array[Bearings::Manifest::Group]
    # @rbs pages: Array[Bearings::Site::Page]
    # @rbs return: Array[Bearings::Site::Group]
    def groups(listed, pages)
      by_source = pages.to_h { |page| [page.source_path, page] }
      listed.map do |group|
        Bearings::Site::Group.new(
          label: group.label,
          pages: group.pages.filter_map { |entry| by_source[entry.source] },
          extras: group.extras
        )
      end
    end
  end
end
