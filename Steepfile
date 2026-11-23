# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature 'sig/generated'
  signature 'sig/manual'
  signature 'sig/_private'

  check 'lib'

  # The gems' signatures, which bin/setup installs.
  collection_config 'rbs_collection.yaml'

  library 'erb'
  library 'json'
  library 'cgi-escape'
  library 'fileutils'
  library 'psych'
  library 'prism'
  library 'cgi-escape'

  configure_code_diagnostics(D::Ruby.all_error)
end
