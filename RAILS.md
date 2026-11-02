# Rails integrations

Shy::Enum has no Rails dependency and never loads Rails by itself. Two opt-in integrations,
for Rails ~> 8.1, plug enums into Rails models:

- [ActiveModel](#activemodel) - an `ActiveModel::Type` for enum attributes, `require "shy/enum/active_model"`
- [ActiveRecord](#activerecord) - the `shy_enum` macro, modeled on Rails' `enum`,
  `require "shy/enum/active_record"`

The examples use this enum:

```ruby
class Status < Shy::Enum::Base
  Draft = new
  Published = new
  Archived = new

  freeze
end
```

## ActiveModel

An opt-in `ActiveModel::Type` for enums. It supports Rails ~> 8.1 (activemodel must be in your
bundle).

In a Rails app, require it from the Gemfile:

```ruby
gem "shy-enum", require: "shy/enum/active_model"
```

Elsewhere, require it yourself:

```ruby
require "shy/enum/active_model"

class Post
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :status, :shy_enum, enum_class: Status, default: Status::Draft
  validates :status, inclusion: { in: Status.all }
end

Post.new(status: "published").status #=> #<Status::Published value="published">
```

The type is registered as `:shy_enum`. It takes `enum_class:`, the enum, and `strict:`
(default `false`).

- Casting a member or a value gives the member. Lookup goes through `Status[]`, so it's by value
  and `before_cast` applies: define it on the enum to cast e.g. strings to integers for string
  columns holding integer values. Labels and Symbols are not looked up: `:draft` is an unknown
  value, and so is `"draft"` when the value of `Draft` is `0`.
- An unknown value is cast to itself, so validations can handle it. A blank value (`nil`, `""`,
  `"  "`) is cast to `nil`.
- No validation is added: add it with `in: Status.all`. The enum class itself can't be used, as
  `Status.include?` is `Module#include?`.
- With `strict: true` an unknown value raises `ArgumentError` on assignment; blank values never
  raise: `attribute :status, :shy_enum, enum_class: Status, strict: true`.
- Serializing gives the member `value`. A member of another enum raises `Shy::Enum::Error` instead
  of an unclear `TypeError` from the database adapter, e.g. in `Post.where(status: Other::Published)`
  with [ActiveRecord](#activerecord).
- Deserializing a value that matches no member returns the value as is. The type doesn't raise
  because Rails deserializes for `inspect`, `attributes` and dirty tracking too: one bad row would
  break them all. With a plain `attribute` an unknown stored value goes unnoticed; the
  [`shy_enum`](#activerecord) reader raises on it.

## ActiveRecord

An opt-in `shy_enum` macro for ActiveRecord models, modeled on Rails' `enum`: the attribute is
stored as the member `value` and read back as the member. It supports Rails ~> 8.1 (activerecord
must be in your bundle).

In a Rails app, require it from the Gemfile:

```ruby
gem "shy-enum", require: "shy/enum/active_record"
```

Elsewhere, `require "shy/enum/active_record"` yourself. Include it in your models, e.g. in
`ApplicationRecord`:

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  include Shy::Enum::ActiveRecordEnum
end

class Post < ApplicationRecord
  shy_enum :status, Status, default: Status::Draft
end

post = Post.create!(status: "published")
post.reload.status #=> #<Status::Published value="published">
post.published?    #=> true
post.draft!        # updates the record
Post.draft         # scope; Post.not_draft too
Post.where(status: Status::Draft)
Post.statuses      #=> {"draft" => #<Status::Draft value="draft">, ...}
```

`require "shy/enum/active_record"` loads the [ActiveModel](#activemodel) type too, and registers
`:shy_enum` in `ActiveRecord::Type`. Nothing is hooked in automatically: include
`Shy::Enum::ActiveRecordEnum` where you need it. You can also use
`attribute :status, :shy_enum, enum_class: Status` without the macro.

`shy_enum name, enum_class` takes:

- `prefix:`, `suffix:` - `true` uses the attribute name
- `scopes:` (default `true`) - `label` and `not_label` scopes
- `instance_methods:` (default `true`) - `label?` and `label!`
- `validate:` (default `false`) - `true` or a Hash of options for `validates_inclusion_of`: an
  unknown value makes the record invalid instead of raising `ArgumentError` on assignment
- any other option goes to `attribute`, e.g. `default:`. `strict:` and `enum_class:` raise
  `ArgumentError`: `shy_enum` sets them itself, from `validate:` and from the second argument

It raises `Shy::Enum::Error` if a generated method, scope or class method already exists, or if
two members have the same label (e.g. `HTTP` and `Http`, both `http`).

Don't use `Shy::Enum::HasEnum` in ActiveRecord models: its `enum` would override Rails' `enum`.
Using Rails' `enum` and `shy_enum` on the same attribute is not supported.

### Same as Rails' enum

On purpose, `shy_enum` behaves like Rails' `enum` here:

- an unknown value raises `ArgumentError` on assignment, e.g. `Post.new(status: "bogus")`.
  `shy_enum` passes `strict: true` to the type, while a plain `attribute` is not strict.
  In a controller this is a 500, not a validation error: pass `validate: true` to get a
  validation error instead
- with `validate:` the inclusion validation is added for you
- blank values (`nil`, `""`, `"  "`) are cast to `nil` and never raise
- `prefix:`, `suffix:`, `scopes:` and `instance_methods:` work the same way, `not_label` scopes
  included
- the generated methods live in a module included in the model, so you can override them and
  call `super`
- a method inherited from `Object` (e.g. `Kernel#open`) is not a conflict, unless the model
  redefines it or Rails reserves it
- `Post.statuses` returns a frozen Hash with indifferent access, keyed by label:
  `Post.statuses[:in_progress]`, `Post.statuses.keys` work as in Rails

### Deviations from Rails' enum

- the reader returns the member, not a label String
- the label used in method and scope names is `member.name.underscore` (`InProgress` gives
  `in_progress`), so it works with Integer values too; the stored value is always the member `value`
- assignment takes members and values only, not labels or Symbols: `Post.new(status: :draft)`
  raises `ArgumentError`, see [ActiveModel](#activemodel)
- a value read from the database that matches no member makes the reader raise
  `Shy::Enum::Error`, where Rails' `enum` returns `nil`: data not aligned with the enum shows up
  right away. The error is raised when reading the attribute, not when loading the record, see
  [Unknown values in the database](#unknown-values-in-the-database)
- with `validate:`, `nil` is valid; Rails' `enum` rejects it unless you pass
  `validate: { allow_nil: true }`. Pass `validate: { allow_nil: false }` to reject it
- the values of `Post.statuses` are the members, not the stored values
- a conflicting method name raises `Shy::Enum::Error`, where Rails' `enum` raises `ArgumentError`
- options `shy_enum` doesn't know go to `attribute`, where Rails' `enum` raises on unknown options

### Unknown values in the database

Say a row holds `"bogus"`, e.g. after a member was removed from the enum:

```ruby
post = Post.find(id)
post.status                 # raises Shy::Enum::Error
post.inspect                #=> #<Post id: 1, status: "bogus">
post.attributes["status"]   #=> "bogus"
post.status_before_type_cast #=> "bogus"
post.as_json                # raises: serialization goes through the reader
post.valid?                 # raises with `validate:`: validation goes through the reader
post.update!(status: Status::Draft) # fixes the row
```

`inspect` and `attributes` keep working, so a bad row can still be found in the console and in
logs. Anything that calls the reader, like `as_json`, `to_json` or views, raises.

### PostgreSQL native enums

This is how it should work; it is not covered by the test suite, which uses SQLite.

- `shy_enum` works with `t.enum` columns, as long as the member values are Strings identical to the
  PG labels. Integer values are not compatible.
- `create_enum :status, Status.values` in a migration creates the PG type from the Shy enum;
  `add_enum_value` adds a member later. PG can't remove labels.
- `order(:status)` follows the order of the PG type, not the `ordinal`.
- `where` with an unknown value raises `PG::InvalidTextRepresentation`.
- A label in the database that has no member makes the `shy_enum` reader raise `Shy::Enum::Error`.
- Array columns are not supported.
