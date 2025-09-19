#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'mcp'
require 'mcp/server/transports/stdio_transport'

# Set up the server
server = MCP::Server.new(
  name: "order_management_server",
  version: "1.0.0"
)

# Simple in-memory storage for orders
orders = []
next_order_id = 1

# Define a tool for creating orders
server.define_tool(
  name: 'create_order',
  description: 'Create a new order in the system',
  input_schema: {
    properties: {
      customer_email: { type: 'string' },
      product_id: { type: 'integer' },
      quantity: { type: 'integer' }
    },
    required: ['customer_email', 'product_id']
  }
) do |customer_email:, product_id:, quantity: nil|
  # Use local variables from closure
  quantity ||= 1

  # Simulate order creation
  order = {
    id: next_order_id,
    customer_email: customer_email,
    product_id: product_id,
    quantity: quantity,
    total_amount: quantity * 99.99 # Mock price
  }

  orders << order
  next_order_id += 1

  MCP::Tool::Response.new([
    {
      type: "text",
      text: "Order created successfully! Order ID: #{order[:id]}, Total: $#{order[:total_amount].round(2)}"
    }
  ])
end

# Create and start the stdio transport
transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open