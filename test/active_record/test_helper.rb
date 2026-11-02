# frozen_string_literal: true

require_relative "../test_helper"
require "shy/enum/active_record"
require "support/active_record_models"

if defined?(SimpleCov)
  SimpleCov.command_name "active_record"
  SimpleCov.cover "lib/shy/enum/active_record.rb" unless ENV.key?("COVERAGE_MERGE")
end
