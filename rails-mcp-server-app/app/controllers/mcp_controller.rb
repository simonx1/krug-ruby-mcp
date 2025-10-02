# frozen_string_literal: true

require "mcp"

class McpController < ActionController::Base

  skip_before_action :verify_authenticity_token

  before_action :handle_preflight
  before_action :authenticate_mcp_request, except: [:options, :head_check]
  before_action :handle_session, except: [:options, :head_check]

  def server_info
    return render_method_not_allowed if json_rpc_method_in_params?

    service_result = McpServerInfo.new(base_url: request.base_url).call
    render json: service_result[:server_info]
  end

  def handle_request
    return handle_sse_post_request if sse_request?

    request_body = request.body.read
    return render_parse_error("Empty request body - JSON-RPC requires request body") if request_body.blank?

    handler_result = McpRequestHandler.new(
      request_body: request_body,
      server_context: @server_context,
      session_data: @mcp_session
    ).call

    if handler_result[:error].present?
      render_parse_error(handler_result[:error])
      return
    end

    @mcp_session = handler_result[:session_data]
    update_session_cache

    return head :no_content if handler_result[:is_notification]

    set_response_headers
    render_mcp_response(handler_result[:mcp_response])
  end

  def options
    head :ok
  end

  def head_check
    formatter_result = McpResponseFormatter.new(response_type: :json_response).call
    formatter_result[:headers].each do |key, value|
      headers[key] = value if key.start_with?("X-MCP-")
    end

    head :ok
  end

  def ping
    service_result = McpServerInfo.new(base_url: request.base_url).call
    render json: service_result[:ping_response]
  end

  def capabilities
    service_result = McpServerInfo.new(base_url: request.base_url).call
    render json: service_result[:capabilities]
  end

  def destroy
    session_service = McpSessionManager.new(
      session_id: request.headers["Mcp-Session-Id"] || @session_id
    )
    session_service.destroy_session

    head :ok
  end

  def catch_all
    render json: {
      error: "not_found",
      message: "Invalid MCP endpoint path",
      attempted_path: request.path
    }, status: :not_found
  end

  private

  def json_rpc_method_in_params?
    request.query_parameters.key?("method")
  end

  def render_method_not_allowed
    render json: {
      error: "method_not_allowed",
      message: "JSON-RPC methods must use POST requests with streamable HTTP transport",
      supported_transport: "streamable-http",
      correct_method: "POST"
    }, status: :method_not_allowed
  end

  def sse_request?
    request.headers["Accept"]&.include?("text/event-stream")
  end

  def update_session_cache
    Rails.cache.write("mcp_session:#{@session_id}", @mcp_session, expires_in: 30.minutes) if @session_id
  end

  def set_response_headers
    formatter_result = McpResponseFormatter.new(response_type: :json_response).call
    formatter_result[:headers].each do |key, value|
      headers[key] = value
    end
    headers["X-MCP-Connection-Id"] = @session_id if @session_id
  end

  def render_mcp_response(mcp_response)
    formatter_result = McpResponseFormatter.new(
      response_type: :json_response,
      data: mcp_response
    ).call
    render json: formatter_result[:response]
  end

  def render_parse_error(data)
    formatter_result = McpResponseFormatter.new(
      response_type: :parse_error,
      error_info: data
    ).call
    render json: formatter_result[:response], status: :bad_request
  end

  def render_server_error(exception)
    Rails.logger.error "MCP Server Error: #{exception.message}"
    Rails.logger.error exception.backtrace.first(5).join("\n") if Rails.env.development?

    render_server_error_with_message(exception.message)
  end

  def render_server_error_with_message(message)
    formatter_result = McpResponseFormatter.new(
      response_type: :server_error,
      error_info: message
    ).call
    render json: formatter_result[:response], status: :internal_server_error
  end

  def send_sse_event(event_type, data)
    response.stream.write "event: #{event_type}\n"
    response.stream.write "data: #{data.to_json}\n\n"
  end

  def send_sse_comment(comment)
    response.stream.write ": #{comment}\n\n"
  end

  def handle_sse_post_request
    set_sse_headers
    handle_session

    request_body = request.body.read
    process_sse_request(request_body)
  ensure
    close_sse_stream
  end

  def set_sse_headers
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers["Connection"] = "keep-alive"
    response.headers["X-Accel-Buffering"] = "no"
    response.headers["X-Buffering"] = "no"
  end

  def process_sse_request(request_body)
    handler_result = McpRequestHandler.new(
      request_body: request_body,
      server_context: @server_context,
      session_data: @mcp_session
    ).call

    response.stream.write ":ok\n\n"

    if handler_result[:mcp_response].present?
      response_data = JSON.parse(handler_result[:mcp_response])
      send_sse_event("message", response_data)
    elsif handler_result[:error].present?
      error_data = {code: -32603, message: "Internal error", data: handler_result[:error]}
      send_sse_event("error", error_data)
    end

    send_sse_event("complete", {timestamp: Time.current.iso8601})
  rescue => e
    send_sse_event("error", {code: -32603, message: "Internal error", data: e.message})
  end

  def close_sse_stream
    response.stream.close
  rescue
    nil
  end

  def handle_session
    session_result = McpSessionManager.new(request_headers: request.headers).call

    @session_id = session_result[:session_id]
    @mcp_session = session_result[:session_data]
    response.headers["Mcp-Session-Id"] = @session_id
  end

  def authenticate_mcp_request
    @server_context = McpAuthentication.authenticate(request)

  rescue McpAuthentication::AuthenticationError => e
    formatter_result = McpResponseFormatter.new(
      response_type: :unauthorized,
      error_info: {base_url: request.base_url, message: e.message}
    ).call

    response.headers["WWW-Authenticate"] = formatter_result[:www_authenticate]
    render json: formatter_result[:response], status: :unauthorized
  end

  def handle_preflight
    if request.method == "OPTIONS"
      head :ok
    end
  end
end
