# frozen_string_literal: true

require 'zeitwerk'
require_relative 'bearings/version'

# for_gem maps lib/bearings/ to Bearings, which fits a gem whose
# constant is its whole name (sample_gem, SampleGem). A dashed gem that extends
# another namespace (riffer-rig, lib/riffer/rig.rb, Riffer::Rig) needs that
# namespace defined first and `Zeitwerk::Loader.for_gem_extension(Riffer)`
# instead, since for_gem would map lib/riffer/ to top-level constants; its
# version.rb then nests `module Riffer` and `module Rig`, because the gemspec
# loads it before Riffer exists.
loader = Zeitwerk::Loader.for_gem
# bearings/rbs needs the rbs gem, which bearings doesn't depend on, so it loads only when required.
loader.ignore("#{__dir__}/bearings/rbs.rb")
loader.setup

module Bearings
end
