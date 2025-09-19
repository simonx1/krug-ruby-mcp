# MCP Ruby Examples - Client-Server Communication

## Overview

This directory contains examples demonstrating the Model Context Protocol (MCP) in Ruby, showing different patterns for client-server communication.

## Examples

### 1. Simple MCP Client-Server
**Files:** `simple_mcp_server.rb`, `simple_mcp_client.rb`

The foundational example demonstrating core MCP concepts with tools and resources.

#### Server Features:
```ruby
# Define a tool with validation
server.define_tool(
  name: 'create_order',
  description: 'Create a new order',
  input_schema: {
    properties: {
      customer_email: { type: 'string' },
      product_id: { type: 'integer' },
      quantity: { type: 'integer' }
    },
    required: ['customer_email', 'product_id']
  }
) do |customer_email:, product_id:, quantity: nil|
  # Process and return response
end

# Define resources
server.resources_list_handler do |_params|
  # Return available resources
end

server.resources_read_handler do |params|
  # Return resource content
end
```

#### Client Usage:
```ruby
# Call tools
result = client.call_tool('create_order', {
  customer_email: 'user@example.com',
  product_id: 123
})

# Read resources
data = client.read_resource('order://list')
```

### 2. Streaming Client-Server
**Files:** `streaming_server.rb`, `streaming_client.rb`

Demonstrates asynchronous task processing with progress updates via stderr.

#### Key Pattern:
```ruby
# Server: Async processing with progress reporting
server.define_tool(name: 'process_items') do |count:|
  task_id = generate_id()

  # Start async work
  Thread.new do
    count.times do |i|
      # Process item
      progress = ((i + 1).to_f / count * 100).round
      $stderr.puts "[PROGRESS] #{progress}%"
    end
  end

  # Return immediately with task ID
  MCP::Tool::Response.new([{
    type: "text",
    text: JSON.pretty_generate({ task_id: task_id })
  }])
end
```

#### Client Flow:
1. Start async task → Get task ID
2. Monitor progress updates (via stderr)
3. Check task status via resources
4. Retrieve results when complete

### 3. Minimal Client-Server
**Files:** `minimal_server.rb`, `minimal_client.rb`

The simplest possible MCP implementation - perfect for understanding the basics.

#### Features:
- Single tool definition
- Basic client connection
- Minimal boilerplate
- Clear demonstration of core concepts

## Concepts Explained

### Tools
Callable functions exposed by the server:
- Defined with name, description, and schema
- Can be synchronous or start async processes
- Return structured responses

### Resources
Data endpoints for reading information:
- Listed via `resources_list_handler`
- Read via `resources_read_handler`
- Support different MIME types

### Streaming Simulation
Since stdio doesn't support real streaming:
- Use stderr for progress updates
- Start async tasks with Thread.new
- Return task ID immediately
- Client polls for status

## Running Examples

### Basic Example
```bash
ruby simple_mcp_client.rb
```

Output shows:
- Tool listing and invocation
- Resource listing and reading
- Order creation and statistics

### Streaming Example
```bash
# See everything
ruby streaming_client.rb 2>&1

# Separate output and progress
ruby streaming_client.rb 2>progress.log
tail -f progress.log  # In another terminal
```

Output shows:
- Main: Task creation and status
- Stderr: Real-time progress updates

## Implementation Notes

### Server Structure
```ruby
# 1. Create server
server = MCP::Server.new(name: "server_name")

# 2. Define capabilities
server.define_tool(...)
server.resources_list_handler { ... }
server.resources_read_handler { ... }

# 3. Start transport
transport = MCP::Server::Transports::StdioTransport.new(server)
transport.open
```

### Client Structure
```ruby
# 1. Configure connection
config = MCPClient.stdio_config(
  command: %w[ruby server.rb],
  name: 'server_name'
)

# 2. Create and connect
client = MCPClient.create_client(mcp_server_configs: [config])
client.servers.each(&:connect)

# 3. Use tools and resources
client.call_tool(...)
client.read_resource(...)
```

## Best Practices

1. **Error Handling**: Always handle tool errors gracefully
2. **Resource Design**: Use clear URI schemes (e.g., `type://identifier`)
3. **Async Tasks**: Store state for status checking
4. **Progress Updates**: Provide meaningful progress information via stderr
5. **Cleanup**: Ensure threads and resources are properly cleaned up

## Troubleshooting

### Common Issues

1. **No progress visible**: Ensure stderr is not redirected to /dev/null
2. **Connection timeout**: Increase sleep after connection
3. **Tool not found**: Check tool name matches exactly
4. **Resource error**: Verify URI format is correct

### Debug Tips
- Add logging to stderr: `$stderr.puts "[DEBUG] ..."`
- Check server is running: `ps aux | grep ruby`
- Test tools directly: Use client REPL if available
- Verify JSON responses: `pp JSON.parse(result)`

## Summary

These examples demonstrate:
- ✅ Core MCP concepts (tools, resources)
- ✅ Client-server communication patterns
- ✅ Async processing with progress updates
- ✅ Different levels of complexity (minimal to full-featured)

The code is designed to be:
- **Simple**: Easy to understand and modify
- **Practical**: Shows real use cases
- **Educational**: Clear patterns for learning MCP
- **Extensible**: Easy to build upon for your own projects