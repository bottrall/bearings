# frozen_string_literal: true

require 'fileutils'
require 'pathname'

module Bearings::Writer
  extend self

  # @rbs files: Array[Bearings::OutputFile]
  # @rbs dir: String
  # @rbs return: Array[Bearings::Problem]
  def call(files, dir)
    problems = duplicates(files)
    write_all(files, dir) if problems.empty?
    problems
  end

  private

  # @rbs files: Array[Bearings::OutputFile]
  # @rbs return: Array[Bearings::Problem]
  def duplicates(files)
    files.map(&:path).tally.select { |_, count| count > 1 }.map do |path, count|
      Bearings::Problem.new(
        check: 'output',
        level: :error,
        file: path,
        line: 1,
        message: "#{count} output files have this path",
        hint: 'give each output its own path'
      )
    end
  end

  # @rbs files: Array[Bearings::OutputFile]
  # @rbs dir: String
  # @rbs return: void
  def write_all(files, dir)
    # Before writing, so a stale file can't block a folder a new path needs (`guide` before `guide/index.html`).
    targets = files.to_h { |file| [File.join(dir, file.path), file] }
    remove_stale(targets.keys, dir)
    targets.each { |target, file| write(file, target) }
  end

  # @rbs targets: Array[String]
  # @rbs dir: String
  # @rbs return: void
  def remove_stale(targets, dir)
    entries = (Dir.glob('**/*', File::FNM_DOTMATCH, base: dir) - ['.']).map { |entry| File.join(dir, entry) }
    folders, existing = entries.partition { |entry| File.directory?(entry) }
    (existing - targets).each { |stale| File.delete(stale) }
    folders.sort_by(&:length).reverse_each { |folder| Dir.rmdir(folder) if Dir.empty?(folder) }
  end

  # @rbs file: Bearings::OutputFile
  # @rbs target: String
  # @rbs return: void
  def write(file, target)
    FileUtils.mkdir_p(File.dirname(target))
    content = file.content
    content.is_a?(Pathname) ? FileUtils.cp(content, target) : File.write(target, content)
  end
end
