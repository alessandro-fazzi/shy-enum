# frozen_string_literal: true

require_relative "enums"

# ActiveModel: the enums on a plain object, no database.
class Ticket
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :status, :shy_enum, enum_class: Status, default: Status::Draft
  attribute :priority, :shy_enum, enum_class: Priority
  validates :status, inclusion: { in: Status.all }
  validates :priority, inclusion: { in: Priority.all }, allow_nil: true
end
