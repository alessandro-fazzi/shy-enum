# frozen_string_literal: true

require_relative "enums"

# In-memory SQLite database.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :posts do |t|
    t.string :title
    t.string :status
    t.integer :priority
  end
end

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  include Shy::Enum::ActiveRecordEnum
end

# `status` is stored as a string, `priority` as an integer.
class Post < ApplicationRecord
  shy_enum :status, Status, default: Status::Draft
  shy_enum :priority, Priority, prefix: true, scopes: false, default: Priority::Low
end
