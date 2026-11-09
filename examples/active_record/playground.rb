#!/usr/bin/env ruby
# frozen_string_literal: true

# ActiveRecord playground on an in-memory SQLite database, created and seeded on every run.
#
#   examples/active_record/playground.rb
#
# It stops at the end with `binding.irb`: the local variables below are available there.

require "bundler/setup"
require "shy/enum/active_record"

# Everything lives here, so the example classes don't leak into the top level.
module Playground
  # Stored as a string.
  class Status < Shy::Enum::Base
    Draft = new
    InProgress = new
    Published = new

    freeze
  end

  # Stored as an integer.
  class Priority < Shy::Enum::Base
    Low = new(0)
    Medium = new(1)
    High = new(2)

    freeze
  end

  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
  ActiveRecord::Schema.verbose = false
  ActiveRecord::Schema.define do
    create_table :posts do |t|
      t.string :title
      t.string :status
      t.integer :priority
    end
  end

  # Base class of the models: includes the opt-in shy-enum integration.
  class ApplicationRecord < ActiveRecord::Base
    primary_abstract_class
    include Shy::Enum::ActiveRecordEnum
  end

  # `status` is stored as a string, `priority` as an integer.
  class Post < ApplicationRecord
    shy_enum :status, Status, default: Status::Draft
    shy_enum :priority, Priority, prefix: true, default: Priority::Low
  end

  # Same enum, but an unknown value makes the record invalid instead of raising.
  class Draft < ApplicationRecord
    self.table_name = "posts"

    shy_enum :status, Status, validate: true, suffix: true
  end

  Post.create!(title: "Hello", status: Status::Published, priority: Priority::High)
  Post.create!(title: "Work in progress", status: Status::InProgress, priority: Priority::Medium)
  Post.create!(title: "Idea")
end

include Playground # rubocop:disable Style/MixinUsage

post = Post.find_by(title: "Hello")
draft = Draft.find_by(title: "Idea")

puts <<~MSG
  In-memory SQLite database with #{Post.count} seeded posts. Everything is in the Playground
  module, included at the top level so the constants below work unprefixed.
  Models: Post (status, priority with prefix), Draft (same table, validate: true, suffix).
  Enums: Status (string), Priority (integer).
  Local variables: `post`, `draft`.
  Try: post.status
       post.published?
       post.priority_low!
       Post.in_progress
       Post.not_draft,
       Post.where(status: Status::Published)
       Post.where(status: "published"
       Post.statuses
       Draft.new(status: "bogus").valid?
       Post.with_connection { it.select_all("SELECT * FROM posts").to_a }
MSG

binding.irb
