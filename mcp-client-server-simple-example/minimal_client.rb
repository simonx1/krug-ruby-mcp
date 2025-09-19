#!/usr/bin/env ruby
require 'bundler/setup'
require 'mcp_client'

# Configure and create client
config = MCPClient.stdio_config(
  command: %w[ruby minimal_server.rb],
  name: 'weather_server'
)

client = MCPClient.create_client(
  mcp_server_configs: [config]
)

# Connect to server
client.servers.each(&:connect)

# List available tools
puts "Available tools:"
client.list_tools.each do |tool|
  puts "  - #{tool.name}: #{tool.description}"
end

# Call a tool
result = client.call_tool('get_weather', { city: 'Tokyo' })
puts "\nResult: #{result['content'][0]['text']}"

# Cleanup
client.cleanup