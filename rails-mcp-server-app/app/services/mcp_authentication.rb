# frozen_string_literal: true
class McpAuthentication
  class AuthenticationError < StandardError; end

  class << self
    def authenticate(request)
      token = extract_bearer_token(request)

      context = authenticate_with_api_key(token, request)
      return context if context

      raise AuthenticationError, "Invalid token"
    end

    private

    def extract_bearer_token(request)
      proxy_auth_header = request.headers["X-MCP-Proxy-Auth"] || request.headers["x-mcp-proxy-auth"]
      authorization_header = request.headers["Authorization"]

      if proxy_auth_header&.start_with?("Bearer ")
        proxy_auth_header.sub("Bearer ", "").strip
      elsif authorization_header&.start_with?("Bearer ")
        authorization_header.sub("Bearer ", "").strip
      else
        raise AuthenticationError, "Missing or invalid Authorization header"
      end
    end

    def authenticate_with_api_key(token, request)
      authenticated = token == ENV['MCP_TOKEN']
      return nil unless authenticated


      build_api_key_context(authenticated, request)
    end

    def build_api_key_context(authenticated, request)
      {
        authenticated: authenticated,
        user: 'jon.doe@example.com',
        request_id: request.uuid,
        user_agent: request.headers["User-Agent"],
        remote_ip: request.remote_ip,
        auth_type: "api_key",
        transport_attempt: detect_transport_type(request),
        request_method: request.method
      }
    end

    def detect_transport_type(request)
      request.headers["Accept"]&.include?("text/event-stream") ? "sse" : "http"
    end

    def parse_scopes(scope_string)
      scope_string&.split(" ") || []
    end
  end
end

