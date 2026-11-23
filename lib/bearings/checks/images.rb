# frozen_string_literal: true

module Bearings::Checks::Images
  extend self

  REMOTE = %r{\A(?:https?:)?//}i #: Regexp
  EXTENSIONS = %w[.avif .gif .jpeg .jpg .png .svg .webp].freeze #: Array[String]

  # @rbs site: Bearings::Site
  # @rbs images: Hash[String, String]
  # @rbs watched: Array[String]
  # @rbs limit_kb: Integer
  # @rbs return: Array[Bearings::Problem]
  def call(site:, images:, watched:, limit_kb:)
    # An <img> with a srcset gives an image per URL, all on one line and with one alt text.
    problems = site.pages.flat_map do |page|
      page.document.images.flat_map { |image| shown(page.source_path, image, images, limit_kb) }
    end.uniq
    [*problems, *unused(watched, Bearings::Images.paths(site))]
  end

  private

  # @rbs file: String
  # @rbs image: Bearings::Document::Image
  # @rbs images: Hash[String, String]
  # @rbs limit_kb: Integer
  # @rbs return: Array[Bearings::Problem]
  def shown(file, image, images, limit_kb)
    path = Bearings::RepoPath.resolve(file, image.src)
    bytes = images[path] if path
    size_kb = bytes.bytesize.fdiv(1024).ceil if bytes
    [
      (undescribed(file, image) if image.alt&.strip&.empty?),
      (missing(file, image, path) if path && !bytes),
      (oversized(file, image, size_kb, limit_kb) if size_kb && size_kb > limit_kb),
      (remote(file, image) if REMOTE.match?(image.src))
    ].compact
  end

  # @rbs watched: Array[String]
  # @rbs used: Array[String]
  # @rbs return: Array[Bearings::Problem]
  def unused(watched, used)
    (watched - used).select { |path| EXTENSIONS.include?(File.extname(path).downcase) }.map do |path|
      problem(
        level: :error,
        file: path,
        line: 1,
        message: 'is in a watched folder but no guide shows it',
        hint: 'show it in a guide, or delete it'
      )
    end
  end

  # @rbs file: String
  # @rbs image: Bearings::Document::Image
  # @rbs return: Bearings::Problem
  def undescribed(file, image)
    problem(
      level: :error,
      file:,
      line: image.line,
      message: 'shows an image with no alt text',
      hint: 'describe the image in its alt text; it is all an agent or a screen reader gets'
    )
  end

  # @rbs file: String
  # @rbs image: Bearings::Document::Image
  # @rbs path: String
  # @rbs return: Bearings::Problem
  def missing(file, image, path)
    problem(
      level: :error,
      file:,
      line: image.line,
      message: "shows `#{image.src}`, which was not found",
      hint: "add the image at #{path}, or fix the path"
    )
  end

  # @rbs file: String
  # @rbs image: Bearings::Document::Image
  # @rbs size_kb: Integer
  # @rbs limit_kb: Integer
  # @rbs return: Bearings::Problem
  def oversized(file, image, size_kb, limit_kb)
    problem(
      level: :error,
      file:,
      line: image.line,
      message: "shows `#{image.src}`, which is #{size_kb} KB, over the #{limit_kb} KB limit",
      hint: 'shrink or compress the image; guides may ship inside a gem, where every image adds to the download'
    )
  end

  # @rbs file: String
  # @rbs image: Bearings::Document::Image
  # @rbs return: Bearings::Problem
  def remote(file, image)
    problem(
      level: :warning,
      file:,
      line: image.line,
      message: "loads `#{image.src}` from another site",
      hint: 'add the image to the repo and point at it by a relative path; a remote image breaks offline and in the gem'
    )
  end

  # @rbs level: :error | :warning
  # @rbs file: String
  # @rbs line: Integer
  # @rbs message: String
  # @rbs hint: String
  # @rbs return: Bearings::Problem
  def problem(level:, file:, line:, message:, hint:)
    Bearings::Problem.new(check: 'image', level:, file:, line:, message:, hint:)
  end
end
