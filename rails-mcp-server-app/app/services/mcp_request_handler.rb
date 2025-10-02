# frozen_string_literal: true

require "mcp"

class McpRequestHandler

  attr_reader :request_body, :server_context, :session_data, :result

  def initialize(request_body:, server_context:, session_data: {})
    @request_body = request_body
    @server_context = server_context
    @session_data = session_data
    @result = {}
  end

  def call
    if request_body.blank?
      result[:error] = "Empty request body"
      return result
    end

    begin
      parsed_request = JSON.parse(request_body)
    rescue JSON::ParserError => e
      result[:error] = e.message
      return result
    end

    result[:parsed_request] = parsed_request

      if initialization_request?(parsed_request)
        handle_initialization(parsed_request)
      end

      mcp_response = process_json_rpc_request

      result[:mcp_response] = mcp_response
      result[:is_notification] = notification_request?(parsed_request)
      result[:session_data] = session_data

    result
  end

  private

  def initialization_request?(parsed)
    parsed && parsed["method"] == "initialize"
  end

  def handle_initialization(parsed)
    session_data[:initialized] = true
    session_data[:client_info] = parsed.dig("params", "clientInfo")
  end

  def notification_request?(parsed)
    parsed&.dig("method") == "notifications/initialized" && parsed["id"].nil?
  end

  def process_json_rpc_request
    server = create_mcp_server
    server.handle_json(request_body)
  end

  def create_mcp_server
    config = MCP::Configuration.new(protocol_version: McpServerInfo::PROTOCOL_VERSION)

    MCP::Server.new(
      name: McpServerInfo::SERVER_NAME,
      version: McpServerInfo::SERVER_VERSION,
      tools: available_tools,
      server_context: server_context,
      configuration: config
    )
  end

  def available_tools
    McpToolRegistry.available_tools(server_context)
  end
end
