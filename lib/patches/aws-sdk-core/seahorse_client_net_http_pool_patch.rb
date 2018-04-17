if Aws::VERSION != "2.9.44"
  raise <<-ERROR.gsub(/ {4}/, '')
    Mismatch Aws::VERSION detected with Seahorse::Client patch!

    Patch file:  #{__FILE__}

    Please review the current version of the `aws-sdk-version` and confirm that
    this patch is still valid.  If it is, simply update the version number
    being checked here at the top of the file.

    If not, determine the best fix (if it is still valid), apply that, and then
    also update the version number in this file.

    To check if the patch is necessary, check out the `aws-sdk-ruby` repo and run:

        $ git clone https://github.com/aws/aws-sdk-ruby.git
        $ cd aws-sdk-ruby
        $ git tag --contains 640297066fff98d248ba957e85858b921e25f1e1

    If the current version is included in those tags, simply remove this file,
    otherwise update the patch (if necessary) and the version number in this file.
  ERROR
end

# Autoload the connection pool
Seahorse::Client::NetHttp::ConnectionPool

module Seahorse
  module Client
    module NetHttp
      class ConnectionPool
        def start_session endpoint

          endpoint = URI.parse(endpoint)

          args = []
          args << endpoint.host
          args << endpoint.port
          args << http_proxy.host
          args << http_proxy.port
          args << (http_proxy.user && CGI::unescape(http_proxy.user))
          args << (http_proxy.password && CGI::unescape(http_proxy.password))

          http = ExtendedSession.new(Net::HTTP.new(*args.compact))
          http.set_debug_output(logger) if http_wire_trace?
          http.open_timeout = http_open_timeout

          if endpoint.scheme == 'https'
            http.use_ssl = true
            if ssl_verify_peer?
              http.verify_mode = OpenSSL::SSL::VERIFY_PEER
              http.ca_file = ssl_ca_bundle if ssl_ca_bundle
              http.ca_path = ssl_ca_directory if ssl_ca_directory
              http.cert_store = ssl_ca_store if ssl_ca_store
            else
              http.verify_mode = OpenSSL::SSL::VERIFY_NONE
            end
          else
            http.use_ssl = false
          end

          http.start
          http
        end
      end
    end
  end
end
