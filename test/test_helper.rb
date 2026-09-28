# frozen_string_literal: true

if ENV["COVERAGE"]
  require "simplecov"
  require "simplecov-console"

  SimpleCov.formatter = SimpleCov::Formatter::Console
  SimpleCov.enable_coverage :branch
  SimpleCov.start do
    skip "/test/"
  end
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "shy/enum"

require "minitest/autorun"
