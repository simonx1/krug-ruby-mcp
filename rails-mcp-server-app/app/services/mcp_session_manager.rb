# frozen_string_literal: true

class McpSessionManager

  DEFAULT_SESSION_EXPIRATION = 30.minutes
  SESSION_DESTROY_TIME = 1.minute
  CACHE_KEY_PREFIX = "mcp_session:"

  attr_reader :session_id, :request_headers, :result

  def initialize(session_id: nil, request_headers: {})
    @session_id = session_id || request_headers["Mcp-Session-Id"]
    @request_headers = request_headers
    @result = {}
  end

  def call
    process_session
    result
  end

  def destroy_session
    return result unless session_id

    session_data = fetch_session_data
    if session_data
      mark_for_cleanup(session_data)
    end

    result[:destroyed] = true
    result
  end

  private

  def process_session
    if session_id.present?
      load_existing_session
    else
      create_new_session
    end

    update_session_data
    persist_session

    result[:session_id] = @session_id
    result[:session_data] = @session_data
  end

  def load_existing_session
    @session_data = fetch_session_data || initialize_session_data
  end

  def create_new_session
    @session_id = SecureRandom.uuid
    @session_data = initialize_session_data
  end

  def initialize_session_data
    {
      created_at: Time.current,
      request_count: 0
    }
  end

  def update_session_data
    @session_data[:request_count] = (@session_data[:request_count] || 0) + 1
    @session_data[:last_request_at] = Time.current
  end

  def persist_session
    Rails.cache.write(cache_key, @session_data, expires_in: DEFAULT_SESSION_EXPIRATION)
  end

  def fetch_session_data
    Rails.cache.fetch(cache_key)
  end

  def mark_for_cleanup(session_data)
    session_data[:marked_for_cleanup] = true
    session_data[:cleanup_requested_at] = Time.current
    Rails.cache.write(cache_key, session_data, expires_in: SESSION_DESTROY_TIME)
  end

  def cache_key
    "#{CACHE_KEY_PREFIX}#{session_id}"
  end
end
