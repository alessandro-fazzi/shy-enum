# frozen_string_literal: true

# With COVERAGE=1 each suite reports the files it tests, from the current run
# only: its own test_helper.rb calls `cover` for them. `rake test:all` sets
# COVERAGE_MERGE to merge the three suites into one report on all of lib/,
# and COVERAGE_SILENT on all suites but the last, so the report prints once.
if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov-console"

  merge = ENV.key?("COVERAGE_MERGE")
  silent = Class.new { def format(_result) = nil }

  SimpleCov.formatter = ENV.key?("COVERAGE_SILENT") ? silent : SimpleCov::Formatter::Console
  SimpleCov.enable_coverage :branch
  SimpleCov.merging merge
  SimpleCov.start do
    skip "/test/"
    # Bundler loads it through the gemspec before SimpleCov starts
    skip "lib/shy/enum/version.rb"
    cover "lib/**/*.rb" if merge
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "shy/enum"

require "minitest/autorun"
