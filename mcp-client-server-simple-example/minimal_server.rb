#!/usr/bin/env ruby
require 'bundler/setup'
require 'mcp'
require 'mcp/server/transports/stdio_transport'

# Create server
server = MCP::Server.new(
  name: "weather_server",
  version: "1.0.0"
)

# Define a simple tool
server.define_tool(
  name: 'get_weather',
  description: 'Get current weather for a city',
  input_schema: {
    properties: {
      city: { type: 'string' }
    },
    required: ['city']
  }
) do |city:|
  # Mock weather data
  temp = rand(15..30)
  conditions = ['sunny', 'cloudy', 'rainy'].sample

  MCP::Tool::Response.new([{
    type: "text",
    text: "Weather in #{city}: #{temp}°C, #{conditions}"
  }])
end

# Start server
transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open