# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "rdoc/task"

Minitest::TestTask.create(:test) { |t| t.test_globs = ["test/shy/**/*_test.rb"] }

namespace :test do
  Minitest::TestTask.create(:active_model) { |t| t.test_globs = ["test/active_model/**/*_test.rb"] }
  Minitest::TestTask.create(:active_record) { |t| t.test_globs = ["test/active_record/**/*_test.rb"] }

  # The suites run as separate processes: the ActiveModel suite checks that
  # ActiveRecord is not loaded.
  desc "Run all test suites; with COVERAGE=1 print one coverage report for all of lib/"
  task :all do
    suites = %w[test test:active_model test:active_record]
    coverage = ENV.key?("COVERAGE")
    if coverage
      rm_rf "coverage"
      ENV["COVERAGE_MERGE"] = "1"
    end

    suites.each_with_index do |suite, i|
      ENV["COVERAGE_SILENT"] = "1" if coverage && i < suites.size - 1
      Rake::Task[suite].invoke
    ensure
      ENV.delete("COVERAGE_SILENT")
    end
  ensure
    ENV.delete("COVERAGE_MERGE")
  end
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "docs"
  rdoc.main = "README.md"
  rdoc.rdoc_files.include("README.md", "RAILS.md", "lib/**/*.rb")
  rdoc.title = "Shy-Enum Documentation"
  rdoc.options << "--markup" << "markdown"
end

task default: %i[test:all rubocop]
