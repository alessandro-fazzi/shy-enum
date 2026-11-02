# frozen_string_literal: true

require_relative "test_helper"

module Shy
  # The type used through ActiveModel::Attributes, as documented in the README.
  class ActiveModelIntegrationTest < Minitest::Test
    class StrictTicket
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :status, :shy_enum, enum_class: Status, strict: true
    end

    def test_lookup
      type = ActiveModel::Type.lookup(:shy_enum, enum_class: Status)

      assert_instance_of Shy::Enum::ActiveModelType, type
      assert_equal :shy_enum, type.type
    end

    def test_default
      ticket = Ticket.new

      assert_equal Status::Draft, ticket.status
      assert_nil ticket.priority
    end

    def test_assignment_casts_values
      ticket = Ticket.new(status: "published", priority: 1)

      assert_equal Status::Published, ticket.status
      assert_equal Priority::High, ticket.priority
      assert_predicate ticket, :valid?
    end

    def test_blank_assignment_is_nil
      ticket = Ticket.new(status: "")

      assert_nil ticket.status
    end

    def test_validation
      ticket = Ticket.new(status: "bogus", priority: 5)

      refute_predicate ticket, :valid?
      assert ticket.errors.of_kind?(:status, :inclusion)
      assert ticket.errors.of_kind?(:priority, :inclusion)
    end

    def test_strict_assignment_raises
      ticket = StrictTicket.new

      error = assert_raises(ArgumentError) { ticket.status = "bogus" }

      assert_equal "'bogus' is not a valid Status", error.message
    end
  end
end
