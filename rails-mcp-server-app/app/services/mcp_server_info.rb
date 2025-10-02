# frozen_string_literal: true

class McpServerInfo

  PROTOCOL_VERSION = "2025-03-26"
  SERVER_NAME = "Krug MCP Server"
  SERVER_VERSION = "1.0.0"

  attr_reader :base_url, :transport_type, :result

  def initialize(base_url:, transport_type: "streamable-http")
    @base_url = base_url
    @transport_type = transport_type
    @result = {}
  end

  def call
    result[:server_info] = build_server_info
    result[:capabilities] = build_capabilities
    result[:ping_response] = build_ping_response
    result
  end

  private

  def build_server_info
    {
      name: SERVER_NAME,
      version: SERVER_VERSION,
      protocol_version: PROTOCOL_VERSION,
      transport: {
        supported: ["streamable-http"],
        current: transport_type
      },
      capabilities: {
        tools: {
          listChanged: false
        },
        resources: {
          subscribe: false,
          listChanged: false
        },
        prompts: {
          listChanged: false
        }
      },
      endpoints: {
        main: "#{base_url}/mcp",
        capabilities: "#{base_url}/mcp/capabilities"
      }
    }
  end

  def build_capabilities
    {
      server: SERVER_NAME,
      version: SERVER_VERSION,
      protocol_version: PROTOCOL_VERSION,
      transport: {
        supported: ["streamable-http"],
        sse_supported: true,
        websocket_supported: false,
        http_only: false
      },
      endpoints: {
        main: "#{base_url}/mcp",
        capabilities: "#{base_url}/mcp/capabilities"
      },
      methods: %w[GET POST],
      auth_required: true,
      oauth_discovery: "#{base_url}/.well-known/oauth-authorization-server",
      dcr_supported: false
    }
  end

  def build_ping_response
    {
      status: "ok",
      server: SERVER_NAME,
      timestamp: Time.current.iso8601,
      transport_supported: ["streamable-http"],
      transport: transport_type
    }
  end
end
