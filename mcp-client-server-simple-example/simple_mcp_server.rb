#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'mcp'
require 'mcp/server/transports/stdio_transport'
require 'json'

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

# Define available resources
server.resources_list_handler do |_params|
  [
    MCP::Resource.new(
      uri: 'order://list',
      name: 'Order List',
      description: 'List of all orders in the system',
      mime_type: 'application/json'
    ).to_h,
    MCP::Resource.new(
      uri: 'order://stats',
      name: 'Order Statistics',
      description: 'Statistics about orders in the system',
      mime_type: 'text/plain'
    ).to_h
  ]
end

# Handle resource reading
server.resources_read_handler do |params|
  case params[:uri]
  when 'order://list'
    [{
      uri: params[:uri],
      mimeType: 'application/json',
      text: JSON.pretty_generate({
        total_orders: orders.length,
        orders: orders
      })
    }]
  when 'order://stats'
    total_revenue = orders.sum { |o| o[:total_amount] }
    total_quantity = orders.sum { |o| o[:quantity] }

    [{
      uri: params[:uri],
      mimeType: 'text/plain',
      text: <<~STATS
        Order Management System Statistics
        ===================================
        Total Orders: #{orders.length}
        Total Revenue: $#{total_revenue.round(2)}
        Total Items Sold: #{total_quantity}
        Average Order Value: $#{orders.empty? ? 0 : (total_revenue / orders.length).round(2)}

        Top Product IDs:
        #{orders.group_by { |o| o[:product_id] }
                .transform_values(&:length)
                .sort_by { |_, count| -count }
                .take(5)
                .map { |id, count| "  - Product #{id}: #{count} orders" }
                .join("\n")}
      STATS
    }]
  else
    raise "Resource not found: #{params[:uri]}"
  end
end

# Create and start the stdio transport
transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open