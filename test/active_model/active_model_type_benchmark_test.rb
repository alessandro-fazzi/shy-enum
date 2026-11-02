# frozen_string_literal: true

require_relative "test_helper"
require "minitest/benchmark"

module Shy
  # Looking up a member must not depend on how many members the enum has.
  class ActiveModelTypeBenchmark < Minitest::Benchmark
    LOOKUPS = 1_000

    def self.bench_range
      bench_linear(500, 4_000, 500)
    end

    # One enum per size, built once: the setup is not part of the measure.
    def self.enum_of(size)
      @enums ||= {}
      @enums[size] ||= Class.new(Shy::Enum::Base).tap do |enum|
        size.times { |i| enum.const_set(:"M#{i}", enum.send(:new)) }
        enum.freeze
      end
    end

    def setup
      self.class.bench_range.each { self.class.enum_of(it) }
    end

    # The threshold allows a slope of 1e-5 seconds per member.
    def bench_assignment_and_read
      assert_performance_constant 0.99999 do |n|
        enum = self.class.enum_of(n)
        type = Shy::Enum::ActiveModelType.new(enum_class: enum, strict: true)
        # The last member is the worst case for a linear scan.
        value = enum.all.last.value

        LOOKUPS.times do
          type.assert_valid_value(value)
          type.cast(value)
          type.deserialize(value)
        end
      end
    end
  end
end
