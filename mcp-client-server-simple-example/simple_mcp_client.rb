#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'mcp_client'

# Create configuration for stdio server
server_config = MCPClient.stdio_config(
  command: %w[ruby simple_mcp_server.rb],
  name: 'order_management_server'
)

# Create MCP client with server configuration
client = MCPClient.create_client(
  mcp_server_configs: [server_config]
)

begin
  # Connect to each server
  puts "Connecting to MCP server..."
  client.servers.each do |server|
    server.connect
  end

  # Wait a moment for the server to initialize
  sleep 1

  # List available tools
  puts "\n=== Available Tools ==="
  tools = client.list_tools
  tools.each do |tool|
    puts "- #{tool.name}: #{tool.description}"
    if tool.schema && tool.schema['properties']
      puts "  Parameters:"
      tool.schema['properties'].each do |param, schema|
        required = tool.schema['required']&.include?(param) ? '(required)' : '(optional)'
        puts "    - #{param}: #{schema['type']} #{required}"
      end
    end
  end

  # Test the create_order tool
  puts "\n=== Testing create_order Tool ==="

  # Test case 1: Create order with minimum required parameters
  puts "\nTest 1: Creating order with required fields only..."
  result1 = client.call_tool('create_order', {
    customer_email: 'john.doe@example.com',
    product_id: 101
  })
  puts "Result: #{result1.inspect}"

  # Test case 2: Create order with all parameters
  puts "\nTest 2: Creating order with all fields..."
  result2 = client.call_tool('create_order', {
    customer_email: 'jane.smith@example.com',
    product_id: 202,
    quantity: 3
  })
  puts "Result: #{result2.inspect}"

  # Test case 3: Create another order
  puts "\nTest 3: Creating another order..."
  result3 = client.call_tool('create_order', {
    customer_email: 'bob@example.com',
    product_id: 303,
    quantity: 5
  })
  puts "Result: #{result3.inspect}"

  puts "\n=== All tests completed successfully! ==="

rescue StandardError => e
  puts "Error: #{e.message}"
  puts e.backtrace
ensure
  # Close the client connection
  puts "\nClosing connection..."
  client.cleanup if client
end