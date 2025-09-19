#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'openai'
require 'byebug'

# Ensure the OPENAI_API_KEY environment variable is set
api_key = ENV.fetch('OPENAI_API_KEY', nil)
abort 'Please set OPENAI_API_KEY' unless api_key

tropic_api_key = ENV.fetch('TROPIC_API_TOKEN', nil)
abort 'Please set TROPIC_API_TOKEN' unless tropic_api_key

client = OpenAI::Client.new(
  access_token: api_key,
  request_timeout: 120,
  log_errors: true
)

mcp_tool = {
  type: "mcp", 
  server_label: "tropic",
  server_url: "https://5bb0309561c0.ngrok.app/mcp",
  authorization: tropic_api_key, 
  require_approval: "never"
}

parameters = {
  model: "gpt-5",
  input: "What is the status of Tropic server?",
  tools: [mcp_tool]
}

response = client.responses.create(parameters:)

text = response.dig("output")&.find { |o| o["type"] == "message" }&.dig("content")&.find { |c| c["type"] == "output_text" }&.dig("text")

puts "GPT-5 response:"
puts '=' * 60
puts text
puts '=' * 60
