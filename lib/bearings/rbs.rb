# frozen_string_literal: true

# Zeitwerk ignores this file, so requiring it on its own loads the gem first.
require 'bearings'
require 'pathname'
require 'rbs'

module Bearings::Rbs
  extend self

  # @rbs dir: String
  # @rbs return: Set[String]
  def declared(dir)
    loader = RBS::EnvironmentLoader.new(core_root: nil)
    loader.add(path: Pathname.new(dir))
    env = RBS::Environment.from_loader(loader)
    [*env.class_decls.keys, *env.class_alias_decls.keys, *env.constant_decls.keys]
      .to_set { |name| name.to_s.delete_prefix('::') }
  end
end
