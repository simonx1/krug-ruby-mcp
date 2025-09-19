#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'mcp'
require 'mcp/server/transports/stdio_transport'
require 'json'

# Simple Streaming MCP Server
# Demonstrates async processing and progress updates

server = MCP::Server.new(
  name: "streaming_server",
  version: "1.0.0"
)

# Store active tasks
$tasks = {}
$task_id = 0

# Tool: Start an async task
server.define_tool(
  name: 'process_items',
  description: 'Process items asynchronously with progress updates',
  input_schema: {
    properties: {
      count: { type: 'integer', description: 'Number of items to process' }
    },
    required: ['count']
  }
) do |count:|
  task_id = ($task_id += 1)

  # Create task record
  task = {
    id: task_id,
    total: count,
    processed: 0,
    status: 'running'
  }
  $tasks[task_id] = task

  # Process asynchronously
  Thread.new do
    count.times do |i|
      sleep 0.5  # Simulate work

      task[:processed] = i + 1
      progress = ((i + 1).to_f / count * 100).round

      # Output progress to stderr (simulating push notification)
      $stderr.puts "[PROGRESS] Task #{task_id}: #{progress}% (#{i + 1}/#{count})"
    end

    task[:status] = 'completed'
    $stderr.puts "[COMPLETE] Task #{task_id} finished!"
  end

  # Return immediate response
  MCP::Tool::Response.new([
    {
      type: "text",
      text: JSON.pretty_generate({
        task_id: task_id,
        message: "Started processing #{count} items"
      })
    }
  ])
end

# Tool: Check task status
server.define_tool(
  name: 'get_status',
  description: 'Get status of a task',
  input_schema: {
    properties: {
      task_id: { type: 'integer', description: 'Task ID' }
    },
    required: ['task_id']
  }
) do |task_id:|
  task = $tasks[task_id]

  if task
    MCP::Tool::Response.new([
      {
        type: "text",
        text: JSON.pretty_generate(task)
      }
    ])
  else
    MCP::Tool::Response.new([
      {
        type: "text",
        text: JSON.pretty_generate({ error: "Task not found" })
      }
    ])
  end
end

# Resource: View all tasks
server.resources_list_handler do |_params|
  [
    {
      uri: 'tasks://all',
      name: 'All Tasks',
      description: 'View all tasks',
      mimeType: 'application/json'
    }
  ]
end

server.resources_read_handler do |params|
  case params[:uri]
  when 'tasks://all'
    [{
      uri: params[:uri],
      mimeType: 'application/json',
      text: JSON.pretty_generate($tasks)
    }]
  else
    raise "Unknown resource"
  end
end

# Start server
puts "Streaming MCP Server"
puts "===================="
puts "Progress updates are sent to stderr"
puts ""

transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open