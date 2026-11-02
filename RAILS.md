# Rails integrations

Shy::Enum doesn't depend on Rails and never loads it by itself. If you use Rails, you can opt into
two integrations:

- [ActiveRecord](#activerecord): the `shy_enum` macro. It works like Rails' `enum`, but the
  attribute reads back as an enum member. Most apps want this one.
- [ActiveModel](#activemodel): an attribute type for models that aren't backed by a table, such as
  form objects. `shy_enum` uses it under the hood.

This guide teaches you how to use them. For the full reference of each method and option, see the
API documentation.

All the examples use this enum:

```ruby
class Status < Shy::Enum::Base
  Draft = new
  InProgress = new
  Published = new
  Archived = new

  freeze
end
```

## ActiveRecord

### Getting started

Your bundle must include `activerecord`, which any Rails app already does. Require the integration
from the Gemfile:

```ruby
gem "shy-enum", require: "shy/enum/active_record"
```

Outside Rails, for example in a script that uses ActiveRecord, call
`require "shy/enum/active_record"` yourself.

Nothing gets added to your models automatically. Include `Shy::Enum::ActiveRecordEnum` wherever you
want the macro. `ApplicationRecord` is usually the right place:

```ruby
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
  include Shy::Enum::ActiveRecordEnum
end
```

Now declare the attribute. You need a column to store the values in, here a string column named
`status`:

```ruby
class Post < ApplicationRecord
  shy_enum :status, Status
end
```

### What you get

The attribute reads back as the enum member, not as a String:

```ruby
post = Post.create!(status: Status::Published)
post.status        #=> #<Status::Published value="published">
post.status.value  #=> "published", the value stored in the column
```

Because you get the member back, any method you define on the enum is ready to use:

```ruby
class Status < Shy::Enum::Base
  # ...members...

  def editable? = self == Draft || self == InProgress
end

post.status.editable?  #=> false
```

Like Rails' `enum`, `shy_enum` also generates a predicate, a bang method and two scopes for each
member:

```ruby
post.published?  #=> true
post.draft!      # sets the status to Draft and saves the record
Post.draft       # posts whose status is Draft
Post.not_draft   # posts whose status is anything else
```

It also adds a class method named after the plural of the attribute, which lists every member by
label:

```ruby
Post.statuses
#=> {"draft" => #<Status::Draft value="draft">, "in_progress" => #<Status::InProgress value="inprogress">, ...}

Post.statuses[:in_progress]  #=> #<Status::InProgress value="inprogress">
```

The Hash is frozen and has indifferent access, so String and Symbol keys both work. It's also what
you'll use to build select boxes, see [Working with forms](#working-with-forms).

#### Where the method names come from

Each member's **label** is its constant name in snake_case. `Draft` becomes `draft`, and
`InProgress` becomes `in_progress`. The label only names things: methods, scopes and keys of
`Post.statuses`. What goes into the column is always the member's `value`. Here that's
`"inprogress"`, because a member's default value is its downcased name.

The method names don't depend on the values, so the macro works with Integer values too:

```ruby
class Priority < Shy::Enum::Base
  Low = new(0)
  High = new(1)

  freeze
end

class Task < ApplicationRecord
  shy_enum :priority, Priority  # integer column
end

task.high?   # stores 1
Task.low     # WHERE priority = 0
```

### Assigning values

In your own code, always assign the member:

```ruby
post.status = Status::Published
```

That's the point of a type-safe enum: you refer to a constant that holds an object, not to a String
that happens to match a value. A typo in `Status::Publshed` raises `NameError` as soon as the line
runs, a rename shows up in a search for `Status::Published`, and the reader learns which enum the
attribute belongs to.

Values are accepted too, but only for input you can't write as a constant: form params, query
strings, JSON payloads, anything that arrives as plain data. The attribute looks the value up and
stores the member:

```ruby
post.status = params[:status]  # "published"
post.status  #=> #<Status::Published value="published">
```

Pass the raw value, don't look it up yourself with `Status[params[:status]]`. The attribute does
the same lookup, but it keeps an unknown value, so that it raises or fails validation (see
[Handling invalid input](#handling-invalid-input)). `Status[]` would turn it into `nil` and
quietly clear the status.

Don't use values as a shortcut in code you write: `post.status = "published"` works, but it's the
stringly-typed code that Shy::Enum is meant to replace.

Labels and Symbols don't work. Lookup goes by value, so `:draft` and `"in_progress"` are unknown
values:

```ruby
Post.new(status: :draft)
# ArgumentError: 'draft' is not a valid Status

Post.new(status: "in_progress")
# ArgumentError: 'in_progress' is not a valid Status (the value is "inprogress")
```

Blank values (`nil`, `""`, `"  "`) become `nil` and are always accepted:

```ruby
Post.new(status: "").status  #=> nil
```

With Integer values, `"1"` doesn't match `1` unless you tell the enum how to convert it. That
happens all the time with form params, see [Integer values from params](#integer-values-from-params).

### Default value

Use `default:` to choose the status of new records:

```ruby
class Post < ApplicationRecord
  shy_enum :status, Status, default: Status::Draft
end

Post.new.status  #=> #<Status::Draft value="draft">
```

Without `default:`, the attribute gets the column default.

### Handling invalid input

By default, assigning an unknown value raises right away, just like Rails' `enum`:

```ruby
Post.new(status: "bogus")
# ArgumentError: 'bogus' is not a valid Status
```

That's fine when the value comes from your own code: it's a bug, and you want to hear about it. When
the value comes from a user, though, the exception becomes a 500 in your controller. Pass
`validate: true` to get a validation error instead:

```ruby
class Post < ApplicationRecord
  shy_enum :status, Status, validate: true
end

post = Post.new(status: "bogus")
post.status              #=> "bogus", kept so you can show it back in the form
post.valid?              #=> false
post.errors.full_messages #=> ["Status is not included in the list"]
```

`nil` is valid with `validate: true`. If the status is required, or if you want another message,
pass a Hash instead: it goes to `validates_inclusion_of`.

```ruby
shy_enum :status, Status, validate: { allow_nil: false, message: "is not a known status" }

Post.new.valid?  #=> false
# errors: ["Status is not a known status"]
```

### Working with forms

Members travel through a form round trip with no glue code. The member's `value` goes into the HTML,
comes back as a param, and gets cast back to the member when you assign it. Let's follow one value
all the way.

#### The form

`Post.statuses` gives you every member. Use the name as the text and the value as the option
value:

```erb
<%= form_with model: @post do |form| %>
  <%= form.text_field :title %>
  <%= form.select :status, Post.statuses.values.map { [it.name, it.value] } %>
  <%= form.submit %>
<% end %>
```

```html
<select name="post[status]" id="post_status">
  <option value="draft">Draft</option>
  <option value="inprogress">InProgress</option>
  <option selected="selected" value="published">Published</option>
  <option value="archived">Archived</option>
</select>
```

The current status is preselected for free. Rails compares each option with `post.status.to_s`,
and a member's `to_s` is its value.

To show something nicer than the constant name, define a method on the enum and use it as the text,
e.g. `[it.title, it.value]`.

#### The request

When the form is submitted, the browser sends the option values as plain text:

```
POST /posts
post[title]=Hello&post[status]=published
```

Rails parses that into params. Everything in params is a String:

```ruby
params #=> {"post" => {"title" => "Hello", "status" => "published"}, ...}
```

#### The controller

Nothing special here: permit `status` like any other attribute and assign it.

```ruby
class PostsController < ApplicationController
  def create
    @post = Post.new(post_params)

    if @post.save
      redirect_to @post
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def post_params
    params.expect(post: [:title, :status])
  end
end
```

On assignment, `"published"` is cast to the member:

```ruby
@post = Post.new(post_params)
@post.status  #=> #<Status::Published value="published">
```

Params come from users, and users (or their browsers' dev tools) can send anything. Declare the
attribute with `validate: true`, so a tampered value fails validation and re-renders the form
instead of raising a 500, see [Handling invalid input](#handling-invalid-input):

```ruby
class Post < ApplicationRecord
  shy_enum :status, Status, validate: true
end
```

#### Filtering with the query string

A filter form usually sends a GET request, so the value shows up in the URL:

```
GET /posts?status=published
```

`where` takes the param as it is. It looks the value up the same way assignment does, so it finds the
same member:

```ruby
def index
  @posts = Post.all
  @posts = @posts.where(status: params[:status]) if params[:status].present?
end
```

An unknown value, like `?status=bogus`, matches no posts. If you'd rather ignore it and show all
posts, look up the member yourself: `Status[]` returns `nil` for an unknown or missing value.

```ruby
def index
  @posts = Post.all
  status = Status[params[:status]]
  @posts = @posts.where(status: status) if status
end
```

That's fine for one filter. With several, or when the filter form needs to remember what the user
picked, use a form object.

#### Filter form objects

A form object is a plain Ruby class with ActiveModel attributes. Give it `:shy_enum` attributes
(see [ActiveModel](#activemodel)), and the casting you get on a record works the same way here.
`require "shy/enum/active_record"` already loads the type.

Enums really pay off here, because a member can carry behavior. Take a period filter where each
member knows how to narrow a relation:

```ruby
class Period < Shy::Enum::Base
  Any = new(title: "Any time", scope: ->(rel) { rel })
  LastWeek = new(title: "Last week", scope: ->(rel) { rel.where(created_at: 1.week.ago..) })
  LastMonth = new(title: "Last month", scope: ->(rel) { rel.where(created_at: 1.month.ago..) })

  def apply(relation) = scope.call(relation)

  freeze
end
```

`Any` is a null member: it stands for "no filter" and leaves the relation alone.

The form object declares one attribute per filter:

```ruby
class PostFilter
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :status, :shy_enum, enum_class: Status
  attribute :period, :shy_enum, enum_class: Period, default: Period::Any

  validates :status, inclusion: { in: Status.all }, allow_nil: true
  validates :period, inclusion: { in: Period.all }

  def apply(relation)
    relation = relation.where(status: status) if status
    period.apply(relation)
  end
end
```

Look at `apply`. By the time it runs, `period` is already a member, so there's no `case` and no
lookup: you call the member's own method. And because `period` defaults to `Any`, it is never
`nil` and doesn't need an `if`. `Status` has no null member, so `status` can be `nil` (hence
`allow_nil: true`) and the filter is skipped in that case.

In the view, build both selects from the members:

```erb
<%= form_with model: @filter, url: posts_path, method: :get do |form| %>
  <%= form.collection_select :status, Status.all, :value, :name, include_blank: "All" %>
  <%= form.collection_select :period, Period.all, :value, :title %>
  <%= form.submit "Filter" %>
<% end %>
```

The null member is the blank choice of its select, so `period` has no `include_blank`. It is also
the selected option when the user hasn't filtered yet: Rails preselects the option matching
`@filter.period.to_s`, which is `"any"` thanks to the `default:`.

```html
<select name="post_filter[period]" id="post_filter_period">
  <option selected="selected" value="any">Any time</option>
  <option value="lastweek">Last week</option>
  <option value="lastmonth">Last month</option>
</select>
```

So the default lives in one place, the attribute, and both the query and the HTML form follow it.
Without a form object, the view would have to repeat it, e.g.
`selected: params[:period].presence || Period::Any.value`.

Submitting the form puts the filters in the URL, under the form object's param key:

```
GET /posts?post_filter[status]=published&post_filter[period]=lastweek
```

In the controller, build the form object from the params and let it do the filtering:

```ruby
class PostsController < ApplicationController
  def index
    @filter = PostFilter.new(filter_params)
    @posts = @filter.valid? ? @filter.apply(Post.all) : Post.none
  end

  private

  def filter_params
    params.fetch(:post_filter, {}).permit(:status, :period)
  end
end
```

Use `fetch` with a default rather than `expect`: on the first visit there are no filter params
at all, and that's not an error.

Here's what the form object does with the params:

```ruby
filter = PostFilter.new("status" => "published", "period" => "lastweek")
filter.status  #=> #<Status::Published value="published">
filter.period  #=> #<Period::LastWeek value="lastweek", title="Last week", ...>
filter.apply(Post.all)
# SELECT "posts".* FROM "posts" WHERE "posts"."status" = 'published' AND "posts"."created_at" >= '...'

PostFilter.new({}).apply(Post.all)
# SELECT "posts".* FROM "posts"
```

The `inclusion` validation on `period` is a safety net for hand-edited URLs. With
`?post_filter[period]=` the blank value becomes `nil`, and the filter is invalid instead of failing
with a `NoMethodError` in `apply`:

```ruby
filter = PostFilter.new("status" => "bogus", "period" => "")
filter.valid?  #=> false
filter.errors.full_messages
#=> ["Status is not included in the list", "Period is not included in the list"]
```

#### Integer values from params

Now the same round trip with an enum whose values are Integers:

```ruby
class Priority < Shy::Enum::Base
  Low = new(0)
  High = new(1)

  freeze
end

class Post < ApplicationRecord
  shy_enum :priority, Priority  # integer column
end
```

The form renders the values, and HTML only knows text:

```html
<option value="0">Low</option>
<option value="1">High</option>
```

So the param comes back as `"1"`, not `1`, and `"1"` matches no member:

```ruby
params.expect(post: [:priority])  #=> {"priority" => "1"}

Post.new(priority: "1")
# ArgumentError: '1' is not a valid Priority

Priority["1"]  #=> nil
```

This is what `before_cast` is for. It's a private class method that every lookup on the enum
(`[]`, `fetch`, `member?`, and so the attribute type too) calls on its input first. Teach the enum
that its values are Integers, so it can read them from Strings:

```ruby
class Priority < Shy::Enum::Base
  Low = new(0)
  High = new(1)

  def self.before_cast(obj) = Integer(obj, exception: false)
  private_class_method :before_cast

  freeze
end
```

Now the whole round trip works, with no change to the form, the controller or the model:

```ruby
Post.new(priority: "1").priority  #=> #<Priority::High value=1>
Post.new(priority: 1).priority    #=> #<Priority::High value=1>

Priority["1"]  #=> #<Priority::High value=1>

Post.where(priority: "1")
# SELECT "posts".* FROM "posts" WHERE "posts"."priority" = 1
```

`where` applies `before_cast` too, so the query sends the Integer `1`, not the String `"1"`, and
doesn't rely on the database to convert it. A value that matches no member, like `"abc"`, is still
sent as it is: on PostgreSQL an integer column rejects it with `PG::InvalidTextRepresentation`. If
the param comes from users, look the member up first with `Priority[params[:priority]]`.

A String that isn't a number becomes `nil` and matches nothing, so it's still treated as an unknown
value:

```ruby
Post.new(priority: "abc")
# ArgumentError: 'abc' is not a valid Priority
```

The conversion belongs to the enum, not to the controller. The enum is the one place that knows its
values are Integers, and every form, controller, job or console session that looks up a member gets
it right.

### Customizing the generated methods

#### Prefix and suffix

When a model has two enum attributes, or a bare `published?` reads ambiguously, add a prefix or a
suffix. With `true`, the attribute name is used:

```ruby
class Post < ApplicationRecord
  shy_enum :status, Status, prefix: true
end

post.status_published?
post.status_draft!
Post.status_archived
Post.not_status_archived
```

You can also choose the word yourself:

```ruby
class Post < ApplicationRecord
  shy_enum :review_status, Status, prefix: :review
  shy_enum :status, Status, suffix: :state
end

post.review_draft?
post.published_state?
Post.draft_state
```

`suffix:` works the same way: `suffix: true` here would give `published_status?`. The keys of
`Post.statuses` are always the bare labels, with no prefix or suffix, as in Rails.

#### Turning off scopes or instance methods

If you don't need the scopes, or if their names clash with something else, turn them off:

```ruby
shy_enum :status, Status, scopes: false

Post.draft  # NoMethodError
Post.where(status: Status::Draft)  # still works
```

The same goes for the predicate and bang methods:

```ruby
shy_enum :status, Status, instance_methods: false

post.draft?  # NoMethodError
post.status == Status::Draft  # still works
```

#### Overriding a generated method

The generated methods live in a module included in the model, so you can override them and call
`super`:

```ruby
class Post < ApplicationRecord
  shy_enum :status, Status

  def published!
    self.published_at = Time.current
    super
  end
end
```

#### Name clashes

`shy_enum` refuses to overwrite a method that already exists, and raises when the model loads:

```ruby
class Post < ApplicationRecord
  def draft? = false
  shy_enum :status, Status
end
# Shy::Enum::Error: Can't define `draft?`: an instance method with that name already exists in Post
```

Use `prefix:` or `suffix:`, or turn off what you don't need. Two members whose labels are the same,
such as `HTTP` and `Http` (both `http`), raise the same error.

Methods every object inherits from Ruby, such as `Kernel#open`, don't count as clashes. A `scope
:open` is defined and shadows them, as with Rails' `enum`.

### Querying

`where` takes members, which are converted to their values for you:

```ruby
Post.where(status: Status::Published)
Post.where(status: [Status::Draft, Status::InProgress])
Post.where.not(status: Status::Archived)
```

As with [assignment](#assigning-values), values are for input you can't write as a constant, such
as a filter from the query string. They are looked up exactly like assignment does, `before_cast`
included, so a query finds the records that assigning the same value would have stored:

```ruby
Post.where(status: params[:status])      # "published"
Post.where(priority: params[:priority])  # "1" gives WHERE priority = 1, with `before_cast` on Priority
```

An unknown value is sent as it is, and matches no records.

If you pass a member of another enum by mistake, you get a clear error instead of an obscure
`TypeError` from the database adapter:

```ruby
Post.where(status: Priority::High).to_a
# Shy::Enum::Error: Can't serialize #<Priority::High value=1>: it is not a member of Status
```

### Unknown values in the database

Say you remove `Archived` from the enum, but some rows still hold `"archived"`. With Rails' `enum`,
the reader would quietly return `nil`. `shy_enum` raises, so data that no longer matches your enum
shows up right away instead of turning into `nil` and spreading:

```ruby
post = Post.find(id)
post.status
# Shy::Enum::Error: Unknown member for value "archived" read from the database
```

Loading the record still works, and so does everything you need to find and fix the bad row:

```ruby
post.inspect                  #=> #<Post id: 1, status: "archived">
post.attributes["status"]     #=> "archived"
post.status_before_type_cast  #=> "archived"
post.update!(status: Status::Draft)  # fixes the row
```

Anything that goes through the reader raises, though: views, `as_json`, `to_json`, and validations
when you use `validate:`.

Before removing a member, migrate the rows that use it:

```ruby
Post.where(status: "archived").update_all(status: Status::Draft.value)
```

### Coming from Rails' enum

Most of `shy_enum` deliberately mirrors Rails' `enum`, so your habits carry over:

- Unknown values raise `ArgumentError` on assignment, and `validate:` turns that into a validation
  error.
- Blank values become `nil` and never raise.
- `prefix:`, `suffix:`, `scopes:` and `instance_methods:` work the same way, `not_` scopes included.
- Generated methods can be overridden with `super`.
- `Post.statuses` is a frozen Hash with indifferent access, keyed by label.
- An unknown option raises `ArgumentError`.

A few things differ, mostly because you get members instead of Strings:

| | Rails' `enum` | `shy_enum` |
| --- | --- | --- |
| `post.status` | `"published"` | `Status::Published` |
| Labels come from | the Hash keys you declare | the member names (`InProgress` → `in_progress`) |
| `post.status = :draft` | works | raises: assign members or values |
| Unknown value in the database | reader returns `nil` | reader raises `Shy::Enum::Error` |
| `nil` with `validate: true` | invalid | valid; pass `{ allow_nil: false }` to reject it |
| `Post.statuses.values` | stored values | members |
| Method name clash | `ArgumentError` | `Shy::Enum::Error` |

> [!WARNING]
> Don't include `Shy::Enum::HasEnum` in ActiveRecord models: its `enum` method would override
> Rails' `enum`. Don't declare Rails' `enum` and `shy_enum` on the same attribute either.

### PostgreSQL native enums

> [!NOTE]
> This section describes how things should work. The test suite runs on SQLite, so it isn't
> covered by tests.

`shy_enum` works with PostgreSQL enum columns, as long as the member values are Strings identical
to the PostgreSQL labels. Integer values won't work.

You can create the PostgreSQL type straight from the enum in a migration:

```ruby
class CreatePosts < ActiveRecord::Migration[8.1]
  def change
    create_enum :post_status, Status.values

    create_table :posts do |t|
      t.enum :status, enum_type: :post_status, default: Status::Draft.value
    end
  end
end
```

When you add a member later, add its value with `add_enum_value :post_status, "review"`.
PostgreSQL can't remove values from an enum type, so removing a member takes more work.

Some differences from a string column:

- `order(:status)` follows the order of the PostgreSQL type, not the order of the members.
- `where` with an unknown value raises `PG::InvalidTextRepresentation`.
- Array columns aren't supported.

## ActiveModel

### Getting started

If your model isn't backed by a table, like a form object or a search filter, use the attribute
type directly. Your bundle must include `activemodel`. In a Rails app, require it from the Gemfile:

```ruby
gem "shy-enum", require: "shy/enum/active_model"
```

Outside Rails, call `require "shy/enum/active_model"` yourself. If you already require
`shy/enum/active_record`, you don't need this: it loads the type too.

The type is registered as `:shy_enum`. Pass it your enum with `enum_class:`:

```ruby
class StatusChange
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :status, :shy_enum, enum_class: Status, default: Status::Draft
end

StatusChange.new(status: "published").status  #=> #<Status::Published value="published">
```

Assignment follows the same rules as with [`shy_enum`](#assigning-values): it accepts members and
values, it doesn't accept labels or Symbols, it turns blank values into `nil`, and it applies
`before_cast`.

For a complete example with a view and a controller, see
[Filter form objects](#filter-form-objects).

### Validating

The plain type is lenient. An unknown value is kept as it is, so you can validate it and show it
back to the user, but no validation is added for you. Add one:

```ruby
class StatusChange
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :status, :shy_enum, enum_class: Status
  validates :status, inclusion: { in: Status.all }
end

form = StatusChange.new(status: "bogus")
form.status  #=> "bogus"
form.valid?  #=> false
form.errors.full_messages  #=> ["Status is not included in the list"]
```

Watch out: pass `Status.all`, not `Status`. On an enum class, `include?` keeps its `Module` meaning,
so the validation fails loudly:

```ruby
validates :status, inclusion: { in: Status }
# TypeError: wrong argument type Status (expected Module). Use `member?` to check for enum members or values
```

Unlike `shy_enum` with `validate: true`, this validation rejects `nil`. Add `allow_nil: true` if the
attribute is optional.

### Strict mode

If an unknown value is always a bug, make the attribute raise on assignment with `strict: true`:

```ruby
attribute :status, :shy_enum, enum_class: Status, strict: true

StatusChange.new(status: "bogus")
# ArgumentError: 'bogus' is not a valid Status

StatusChange.new(status: "").status  #=> nil, blank values never raise
```

`shy_enum` works this way when you don't pass `validate:`.

### Using the type in an ActiveRecord model

The type also works in ActiveRecord models without the macro, for example for an attribute with no
column, or when you don't want the generated methods:

```ruby
class Post < ApplicationRecord
  attribute :status, :shy_enum, enum_class: Status
end
```

You get casting and serialization, and nothing else: no predicates, no scopes, no `Post.statuses`,
no strict mode unless you pass `strict: true`. One more difference: when the database holds a value
that matches no member, the plain attribute returns it as a String instead of raising. The type
can't raise there, because Rails also reads values for `inspect`, `attributes` and dirty tracking,
and one bad row would break all of them. The `shy_enum` reader does the check instead. Prefer the
macro unless you have a reason not to.
