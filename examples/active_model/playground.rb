#!/usr/bin/env ruby
# frozen_string_literal: true

# ActiveModel playground: no database, plain objects with `shy_enum` attributes.
#
# It stops at the end with `binding.irb`: the local variables below are available there.

require "bundler/setup"
require "shy/enum/active_model"

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

  # Unknown values are kept as they are and caught by the inclusion validations.
  class Ticket
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :status, :shy_enum, enum_class: Status, default: Status::Draft
    attribute :priority, :shy_enum, enum_class: Priority
    validates :status, inclusion: { in: Status.all }
    validates :priority, inclusion: { in: Priority.all }, allow_nil: true
  end

  # Strict: an unknown value raises ArgumentError on assignment.
  class StrictTicket
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :status, :shy_enum, enum_class: Status, strict: true
  end
end

include Playground # rubocop:disable Style/MixinUsage

ticket = Ticket.new(status: "inprogress", priority: 1)
strict_ticket = StrictTicket.new(status: Status::Published)

puts <<~MSG
  Everything is in the Playground module, included at the top level so the constants
  below work unprefixed.
  Models: Ticket (validations), StrictTicket (raises on unknown values).
  Enums: Status (string), Priority (integer).
  Variables: `ticket`, `strict_ticket`.
  Try: ticket.status
       ticket.priority
       Ticket.new.status
       ticket.status = "bogus"; ticket.valid?,
       ticket.errors.full_messages
       ticket.status = ""; ticket.status,
       strict_ticket.status = "bogus"
MSG

binding.irb
