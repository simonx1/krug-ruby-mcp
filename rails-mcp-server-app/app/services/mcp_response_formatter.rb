# frozen_string_literal: true

class McpResponseFormatter

  attr_reader :response_type, :data, :request_id, :error_info, :result

  def initialize(response_type:, data: nil, request_id: nil, error_info: nil)
    @response_type = response_type
    @data = data
    @request_id = request_id
    @error_info = error_info
    @result = {}
  end

  def call
    response = case response_type
               when :parse_error
                 format_parse_error
               when :server_error
                 format_server_error
               when :empty_response
                 format_empty_response_error
               when :json_response
                 format_json_response
               when :unauthorized
                 format_unauthorized_response
               else
                 result[:error] = "Unknown response type: #{response_type}"
                 nil
               end

    result[:response] = response
    result[:headers] = build_headers
    result
  end

  private

  def format_parse_error
    {
      jsonrpc: "2.0",
      error: {
        code: -32700,
        message: "Parse error",
        data: error_info
      },
      id: request_id
    }
  end

  def format_server_error
    {
      jsonrpc: "2.0",
      error: {
        code: -32603,
        message: "Internal error",
        data: error_info
      },
      id: request_id
    }
  end

  def format_empty_response_error
    {
      jsonrpc: "2.0",
      error: {
        code: -32603,
        message: "Internal error - empty response"
      },
      id: request_id
    }
  end

  def format_json_response
    return format_empty_response_error if data.blank? || data.strip.empty?

    JSON.parse(data)
  rescue JSON::ParserError => e
    Rails.logger.error "MCP Invalid JSON response: #{e.message}"
    format_empty_response_error
  end

  def format_unauthorized_response
    base_url = error_info[:base_url]
    message = error_info[:message]
    resource_metadata_url = "#{base_url}/.well-known/oauth-protected-resource/mcp"

    result[:www_authenticate] = build_www_authenticate_header(message, resource_metadata_url)

    {
      error: "unauthorized",
      error_description: message || "Authorization required",
      _links: {
        "oauth-authorization-server": {
          href: "#{base_url}/.well-known/oauth-authorization-server"
        },
        "oauth-protected-resource": {
          href: resource_metadata_url
        }
      }
    }
  end

  def build_www_authenticate_header(message, resource_metadata_url)
    "Bearer realm=\"MCP Server\", " \
      "error=\"invalid_token\", " \
      "error_description=\"#{message.gsub('"', '\\"')}\", " \
      "resource_metadata=\"#{resource_metadata_url}\""
  end

  def build_headers
    headers = {
      "Content-Type" => "application/json; charset=utf-8",
      "Connection" => "keep-alive",
      "X-Accel-Buffering" => "no",
      "X-Buffering" => "no",
      "X-MCP-Transport" => "streamable-http",
      "X-MCP-Protocol" => "json-rpc-2.0",
      "X-MCP-Transport-Supported" => "streamable-http",
      "X-MCP-Protocol-Version" => McpServerInfo::PROTOCOL_VERSION,
      "X-MCP-Streaming" => "true",
      "X-MCP-SSE-Supported" => "true",
      "X-MCP-WebSocket-Supported" => "false",
      "X-MCP-Auth-Version" => McpServerInfo::PROTOCOL_VERSION
    }

    headers["WWW-Authenticate"] = result[:www_authenticate] if result[:www_authenticate]
    headers
  end
end
