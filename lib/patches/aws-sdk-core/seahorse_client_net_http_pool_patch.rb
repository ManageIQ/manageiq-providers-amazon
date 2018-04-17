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
