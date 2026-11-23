# frozen_string_literal: true

require 'net/http'

module Bearings::NetHttp
  extend self

  REDIRECTS = 5 #: Integer
  TIMEOUT = 10 #: Numeric

  # @rbs url: String
  # @rbs timeout: Numeric
  # @rbs return: Integer | Bearings::Checks::ExternalLinks::Failure
  def status(url, timeout: TIMEOUT)
    follow(URI(url), REDIRECTS, timeout)
  rescue Timeout::Error
    Bearings::Checks::ExternalLinks::Failure.new(reason: "timed out after #{timeout}s", timed_out: true)
  rescue IOError, SocketError, SystemCallError, OpenSSL::SSL::SSLError, Net::ProtocolError, Net::HTTPBadResponse,
         URI::Error => e
    failure(e.message)
  end

  private

  # @rbs uri: URI::Generic
  # @rbs redirects: Integer
  # @rbs timeout: Numeric
  # @rbs return: Integer | Bearings::Checks::ExternalLinks::Failure
  def follow(uri, redirects, timeout)
    host = uri.host
    return failure("#{uri} is not an http or https URL") unless uri.is_a?(URI::HTTP) && host

    options = { use_ssl: uri.is_a?(URI::HTTPS), open_timeout: timeout, read_timeout: timeout, write_timeout: timeout }
    response = Net::HTTP.start(host, uri.port, **options) { |http| http.request(Net::HTTP::Get.new(uri)) }
    location = response['location']
    return response.code.to_i unless response.is_a?(Net::HTTPRedirection) && location
    return failure("redirected more than #{REDIRECTS} times") if redirects.zero?

    follow(uri + location, redirects - 1, timeout)
  end

  # @rbs reason: String
  # @rbs return: Bearings::Checks::ExternalLinks::Failure
  def failure(reason)
    Bearings::Checks::ExternalLinks::Failure.new(reason:, timed_out: false)
  end
end
