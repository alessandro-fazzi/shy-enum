# frozen_string_literal: true

require_relative "../test_helper"

if defined?(SimpleCov)
  SimpleCov.command_name "shy"
  unless ENV.key?("COVERAGE_MERGE")
    SimpleCov.cover "lib/shy/enum.rb", "lib/shy/enum/base.rb", "lib/shy/enum/has_enum.rb", "lib/shy/enum/error.rb"
  end
end
