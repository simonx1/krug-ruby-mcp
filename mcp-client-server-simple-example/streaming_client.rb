#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'mcp_client'
require 'json'

# Simple Streaming MCP Client

# Configure server
server_config = MCPClient.stdio_config(
  command: %w[ruby streaming_server.rb],
  name: 'streaming_server'
)

# Create client
client = MCPClient.create_client(
  mcp_server_configs: [server_config]
)

begin
  puts "\n🚀 Streaming MCP Client"
  puts "=" * 40

  # Connect
  puts "\nConnecting..."
  client.servers.each(&:connect)
  sleep 1
  puts "✓ Connected"

  # Start a task
  puts "\n📋 Starting async task..."
  result = client.call_tool('process_items', { count: 5 })
  response = JSON.parse(result['content'].first['text'])
  task_id = response['task_id']

  puts "✓ Task #{task_id} started"
  puts "\n⏳ Processing (watch for progress in stderr)..."

  # Check status periodically
  3.times do
    sleep 2
    status = client.call_tool('get_status', { task_id: task_id })
    task = JSON.parse(status['content'].first['text'])
    puts "  Status: #{task['processed']}/#{task['total']} - #{task['status']}"
  end

  # Check all tasks
  puts "\n📊 All tasks:"
  tasks = client.read_resource('tasks://all')
  all_tasks = JSON.parse(tasks.first.text)
  all_tasks.each do |id, task|
    puts "  Task #{id}: #{task['processed']}/#{task['total']} - #{task['status']}"
  end

  puts "\n✨ Done!"

rescue => e
  puts "\n❌ Error: #{e.message}"
ensure
  client&.cleanup
end