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
  library 'net-http'
  library 'openssl'
  library 'socket'
  library 'did_you_mean'
  # The collection leaves out gems the Gemfile doesn't require, and rbs ships its own signatures.
  library 'rbs'

  configure_code_diagnostics(D::Ruby.all_error)
end
