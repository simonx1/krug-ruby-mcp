# frozen_string_literal: true

class McpToolRegistry

  attr_reader :server_context, :result

  def self.available_tools(server_context)
    result = new(server_context:).call
    result.present? ? result[:tools] : []
  end

  def initialize(server_context:)
    @server_context = server_context
    @result = {}
  end

  def call
    tools = build_tool_list
    result[:tools] = tools
    result[:tool_count] = tools.size
    result
  end

  private

  def build_tool_list
    [McpTools::ServerStatusTool]
  end
end
