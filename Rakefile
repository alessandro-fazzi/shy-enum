# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"
require "rdoc/task"

Minitest::TestTask.create

require "rubocop/rake_task"

RuboCop::RakeTask.new

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "docs"
  rdoc.main = "README.md"
  rdoc.rdoc_files.include("README.md", "lib/**/*.rb")
  rdoc.options << "--root" << "lib"
  rdoc.options << "--template" << "rorvswild"
  rdoc.options << "--markup" << "markdown"
end

task default: %i[test rubocop]
