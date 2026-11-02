# frozen_string_literal: true

require_relative "../test_helper"
require "shy/enum/active_model"
require "support/active_model_models"

if defined?(SimpleCov)
  SimpleCov.command_name "active_model"
  SimpleCov.cover "lib/shy/enum/active_model.rb" unless ENV.key?("COVERAGE_MERGE")
end
