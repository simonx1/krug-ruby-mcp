# frozen_string_literal: true

Rails.application.config.after_initialize do
  Rails.configuration.x.booted_at = Time.current
end

# nice shortcut that won't clash with future Rails versions
module Rails
  def self.booted_at = Rails.configuration.x.booted_at
end
