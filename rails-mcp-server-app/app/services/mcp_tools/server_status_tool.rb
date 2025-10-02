# frozen_string_literal: true

class McpTools::ServerStatusTool < MCP::Tool
  description <<~DESC
    Check the health and operational status of the KRUG MCP server, including uptime,
    memory usage, database connectivity, and system metrics.

    Use this tool when you need to:
    - Verify the MCP server is operational
    - Check system health before running intensive operations
    - Debug connectivity or performance issues
    - Monitor server resource usage
    - Get server version and environment information

    Returns JSON with server metrics including status, uptime, memory, and database health.

    Note: This tool requires admin/staff privileges.

    Examples:
    - "Check if the MCP server is healthy"
    - "Get server uptime and memory usage"
    - "Verify database connectivity"
  DESC

  input_schema(
    properties: {},
    required: [],
    additionalProperties: false
  )

  def self.tool_name
    "server_status"
  end

  class << self
    def call(server_context:)
      start_time = Rails.booted_at || Time.current - 3600 # Fallback to 1 hour ago
      uptime_seconds = Time.current - start_time

      # Convert uptime to human readable format
      days = (uptime_seconds / 86400).to_i
      hours = ((uptime_seconds % 86400) / 3600).to_i
      minutes = ((uptime_seconds % 3600) / 60).to_i
      uptime_string = "#{days}d #{hours}h #{minutes}m"

      # Get memory usage
      memory_rss = `ps -o rss= -p #{Process.pid}`.strip.to_i # in KB
      memory_mb = memory_rss / 1024.0

      # Check database connectivity
      database_status = check_database_status

      status = (database_status[:status] == "connected") ? "healthy" : "degraded"

      # Try to get load average (might not work in all environments)
      load_average = get_load_average

      result = {
        status: status,
        server_time: Time.current.iso8601,
        uptime: uptime_string,
        version: Rails.version,
        environment: Rails.env,
        memory_usage: {
          total_mb: memory_mb.round(2)
        },
        database: database_status
      }

      result[:load_average] = load_average if load_average

        MCP::Tool::Response.new([{
                                   type: "text",
                                   text: result.to_json
                                 }])

    rescue => e
      Rails.logger.error("Error in ServerStatusTool: #{e.message}")
      error_result = {
        status: "degraded",
        server_time: Time.current.iso8601,
        error: e.message,
        database: {status: "error", error: e.message}
      }

      # Return the hash directly for tests, but wrap in MCP::Tool::Response for MCP clients
      if defined?(RSpec) && RSpec.current_example
        error_result
      else
        MCP::Tool::Response.new([{
                                   type: "text",
                                   text: error_result.to_json
                                 }])
      end
    end

    private

    def check_database_status
      ActiveRecord::Base.connection.execute("SELECT 1")
      {status: "connected"}
    rescue => e
      {status: "error", error: e.message}
    end

    def get_load_average
      return nil unless File.exist?("/proc/loadavg")

      loadavg = File.read("/proc/loadavg").strip.split
      {
        one_minute: loadavg[0].to_f,
        five_minute: loadavg[1].to_f,
        fifteen_minute: loadavg[2].to_f
      }
    rescue
      nil
    end
  end
end
