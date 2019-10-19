require 'fcmpush/exceptions'
require 'fcmpush/json_response'

module Fcmpush
  V1_ENDPOINT_PREFIX = '/v1/projects/'.freeze
  V1_ENDPOINT_SUFFIX = '/messages:send'.freeze
  TOPIC_DOMAIN = 'https://iid.googleapis.com'.freeze
  TOPIC_ENDPOINT_PREFIX = '/iid/v1'.freeze

  class Client
    attr_reader :domain, :path, :connection, :access_token, :configuration, :server_key

    def initialize(domain, project_id, configuration, **options)
      @domain = domain
      @project_id = project_id
      @path = V1_ENDPOINT_PREFIX + project_id.to_s + V1_ENDPOINT_SUFFIX
      @options = {}.merge(options)
      @configuration = configuration
      @access_token = v1_authorize
      @server_key = configuration.server_key
      @connection = Net::HTTP::Persistent.new
    end

    def v1_authorize
      @auth ||= if configuration.json_key_io
                  Google::Auth::ServiceAccountCredentials.make_creds(
                    json_key_io: File.open(configuration.json_key_io),
                    scope: configuration.scope
                  )
                else
                  # from ENV
                  Google::Auth::ServiceAccountCredentials.make_creds(scope: configuration.scope)
                end
      @auth.fetch_access_token!['access_token']
    end

    def push(body, query: {}, headers: {})
      uri, request = make_push_request(body, query, headers)
      response = exception_handler(connection.request(uri, request))
      JsonResponse.new(response)
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      raise NetworkError, "A network error occurred: #{e.class} (#{e.message})"
    end

    def subscribe(topic, *instance_ids, query: {}, headers: {})
      uri, request = make_subscription_request(topic, *instance_ids, :subscribe, query, headers)
      response = exception_handler(connection.request(uri, request))
      JsonResponse.new(response)
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      raise NetworkError, "A network error occurred: #{e.class} (#{e.message})"
    end

    def unsubscribe(topic, *instance_ids, query: {}, headers: {})
      uri, request = make_subscription_request(topic, *instance_ids, :unsubscribe, query, headers)
      response = exception_handler(connection.request(uri, request))
      JsonResponse.new(response)
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      raise NetworkError, "A network error occurred: #{e.class} (#{e.message})"
    end

    private

      def make_push_request(body, query, headers)
        uri = URI.join(domain, path)
        uri.query = URI.encode_www_form(query) unless query.empty?

        headers = v1_authorized_header(headers)
        post = Net::HTTP::Post.new(uri, headers)
        post.body = body.is_a?(String) ? body : body.to_json

        [uri, post]
      end

      def make_subscription_request(topic, instance_ids, type, query, headers)
        suffix = type == :subscribe ? ':batchAdd' : ':batchRemove'

        uri = URI.join(TOPIC_DOMAIN, TOPIC_ENDPOINT_PREFIX + suffix)
        uri.query = URI.encode_www_form(query) unless query.empty?

        headers = legacy_authorized_header(headers)
        post = Net::HTTP::Post.new(uri, headers)
        post.body = make_subscription_body(topic, *instance_ids)

        [uri, post]
      end

      def v1_authorized_header(headers)
        headers.merge('Content-Type' => 'application/json',
                      'Accept' => 'application/json',
                      'Authorization' => "Bearer #{access_token}")
      end

      def legacy_authorized_header(headers)
        headers.merge('Content-Type' => 'application/json',
                      'Accept' => 'application/json',
                      'Authorization' => "Bearer key=#{server_key}")
      end

      def exception_handler(response)
        error = STATUS_TO_EXCEPTION_MAPPING[response.code]
        raise error.new("Receieved an error response #{response.code} #{error.to_s.split('::').last}: #{response.body}", response) if error

        response
      end

      def make_subscription_body(topic, *instance_ids)
        topic = topic.match?(%r{^/topics/}) ? topic : '/topics/' + topic
        {
          to: topic,
          registration_tokens: instance_ids
        }.to_json
      end
  end
end
