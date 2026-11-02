# Shy::Enum

Shy::Enum is a small, dependency-free way to define enums in plain Ruby. Each member is a
frozen object with a name, a value and an ordinal position, so members are comparable, can be
looked up by value and carry extra attributes. A closed enum can't gain new members, and
[`HasEnum`](#hasenum) plugs an enum into any class with a reader, a writer and predicate methods.
Optional integrations for [ActiveModel](RAILS.md#activemodel) and
[ActiveRecord](RAILS.md#activerecord) are opt-in.

```ruby
class Color < Shy::Enum::Base
  Pink = new
  Red = new
  Violet = new

  freeze
end

Color::Red       #=> #<Color::Red value="red">
Color::Red.value #=> "red"
```

See [Installation](#installation) to add it to a project.

## Usage

### Default values

```ruby
class Color < Shy::Enum::Base
  Red = new       # value is automatically set to "red"
  Green = new     # value is automatically set to "green"
  Blue = new      # value is automatically set to "blue"

  freeze
end

Color::Red.value #=> "red"
Color::Green.value #=> "green"
Color::Blue.value #=> "blue"
```

### Setting integer values

```ruby
class Status < Shy::Enum::Base
  Draft = new(0)
  Published = new(1)
  Archived = new(2)

  freeze
end

Status::Draft.value #=> 0
Status::Published.value #=> 1
Status::Archived.value #=> 2
```

`to_s` always returns the value as a String:

```ruby
Status::Published.to_s #=> "1"
```

### Setting arbitrary string values

By default member value will automatically be set to the downcased name (String),
but you can set arbitrary values.

```ruby
class Role < Shy::Enum::Base
  Admin = new("administrator")
  User = new("regular_user")
  Guest = new("guest")

  freeze
end

Role::Admin.value #=> "administrator"
Role::User.value #=> "regular_user"
Role::Guest.value #=> "guest"
```

### Extra attributes

Keyword arguments passed to `new` become attributes with a reader, like a Struct.
Members without an attribute return `nil`; the value stays the positional argument.

```ruby
class Color < Shy::Enum::Base
  Red = new(hex: "ff0000")
  Green = new("verde", hex: "00ff00")
  Blue = new

  freeze
end

Color::Red.hex     #=> "ff0000"
Color::Green.hex   #=> "00ff00"
Color::Green.value #=> "verde"
Color::Blue.hex    #=> nil
```

Attributes are already set when `after_initialize` runs. An attribute can't override
an existing method, e.g. `new(name: "foo")` raises `Shy::Enum::Error`:

```ruby
class Color < Shy::Enum::Base
  Red = new(name: "foo")
  #=> Shy::Enum::Error "`name` is a reserved method and can't be overridden by an attribute reader"
end
```

### After initialize

Override `after_initialize` to refine a member right after it is built, e.g. to derive
extra state from its attributes. There's no need to call `super` or to override `initialize`.

```ruby
class Color < Shy::Enum::Base
  attr_reader :label

  def after_initialize
    @label = "##{hex.upcase}"
  end

  Red = new(hex: "ff0000")

  freeze
end

Color::Red.label #=> "#FF0000"
```

The [extra attributes](#extra-attributes) are already set and so are the positional
value, when given, and the ordinal. The `name` is not: it's assigned when the constant is
defined, and so is the default value. The member is also still unfrozen, so it can be
modified here.

> [!IMPORTANT]
> Define `after_initialize` before the members, as in the example: it runs
> while each member is being built, so members declared above it won't call it.

### Custom methods

Members are plain Ruby objects, so you can add your own methods to the enum, on the
members and on the class itself. Members are comparable, which makes a state machine
easy to model:

```ruby
class IssueState < Shy::Enum::Base
  New = new
  Triaged = new
  InProgress = new("in_progress")
  Review = new
  Done = new

  # Between triage and completion
  def working? = Triaged < self && self < Done

  def self.working = select(&:working?)

  freeze
end

IssueState::New.working?        #=> false
IssueState::InProgress.working? #=> true
IssueState::Done.working?       #=> false
IssueState.working.map(&:value) #=> ["in_progress", "review"]
```

Define the methods before calling `freeze`: a frozen enum can't be changed any more.

### Inspecting members

`inspect` shows the value and the instance variables of the member, mimicking `Data`.
Each [extra attribute](#extra-attributes) is stored in an instance variable of the same
name (`hex` in `@hex`), which is why it shows up here, with the `Color` from
[Extra attributes](#extra-attributes):

```ruby
Color::Red.inspect   #=> #<Color::Red value="red", hex="ff0000">
Color::Blue.inspect  #=> #<Color::Blue value="blue">
```

To choose what to show, override the private `instance_variables_to_inspect`:

```ruby
class ApiKey < Shy::Enum::Base
  Public = new(token: "abc")

  private

  def instance_variables_to_inspect = %i[@value]

  freeze
end

ApiKey::Public.inspect #=> #<ApiKey::Public value="public">
```

### Comparing enum members

The comparison is based on the enum member's ordinal position, which is assigned in declaration order.

```ruby
class Status < Shy::Enum::Base
  Draft = new
  Published = new
  Archived = new

  freeze
end

Status::Draft < Status::Published    #=> true
Status::Published > Status::Draft    #=> true
Status::Archived > Status::Published #=> true
Status::Draft < Status::Archived     #=> true

Status::Draft <=> Status::Published     #=> -1
Status::Published <=> Status::Published #=> 0
Status::Archived <=> Status::Published  #=> 1
Status::Draft == Status::Draft          #=> true
Status::Draft == Status::Published      #=> false
```

Members are only comparable with members of the same enum: with any other object
`<=>` returns `nil` and `==` returns `false`.

```ruby
Status::Draft <=> "draft" #=> nil
Status::Draft == "draft"  #=> false
```

### Using in case statements

Enum members can be used in case statements thanks to Ruby's `===` operator. Here's how it works:

```ruby
class Status < Shy::Enum::Base
  Draft = new
  Published = new
  Archived = new
  freeze
end

status = Status::Published

# Ruby uses === internally for case statements
# This is equivalent to Status::Draft === status
case status
when Status::Draft
  puts "Still working on it"
when Status::Published
  puts "Live and ready"
when Status::Archived
  puts "No longer active"
end
# prints "Live and ready"

# You can also use it directly
Status::Published === status #=> true
Status::Draft === status    #=> false
```

### Iterating members

The enum class is `Enumerable` over its members, in declaration order. With the `Color`
from the top of this page:

```ruby
Color.each { puts it.name }    # prints Pink, Red, Violet
Color.map(&:value)             #=> ["pink", "red", "violet"]
Color.size                     #=> 3
```

### Looking up members

`[]` finds a member by member or by value and returns `nil` when nothing matches.
`fetch` (aliased as `cast`) does the same, but raises `Shy::Enum::Error`.

```ruby
Color["red"]          #=> #<Color::Red value="red">
Color[Color::Red]     #=> #<Color::Red value="red">
Color["brown"]        #=> nil
Color.fetch("red")    #=> #<Color::Red value="red">
Color.cast("brown")   # raises: Unknown member for value "brown" (Shy::Enum::Error)
```

Values are compared strictly: with the `Status` from [Setting integer values](#setting-integer-values),
`Status["1"]` doesn't find the member whose value is `1`. Lookup uses a Hash, so values are compared
with `eql?`, not `==`: `Status[1.0]` doesn't find `1` either. To convert the input before the
lookup, e.g. strings coming from request params, override the private `before_cast` class method.
Define it before calling `freeze`:

```ruby
class Status < Shy::Enum::Base
  Draft = new(0)
  Published = new(1)

  def self.before_cast(obj) = Integer(obj, exception: false)
  private_class_method :before_cast

  freeze
end

Status["1"] #=> Status::Published
```

`member?` tells whether `[]` would find something, so it accepts members and values and
applies `before_cast` too.

```ruby
Color.member?(Color::Red) #=> true
Color.member?("red")      #=> true
Color.member?("brown")    #=> false
```

> [!NOTE]
> Use `member?`, not `include?`. `include?` keeps its `Module` meaning (whether
> a module is included) and raises `TypeError` when given anything but a module.

### Exceptions

Errors raised by the library are instances of `Shy::Enum::Error`, except for `FrozenError`
when modifying a member and `TypeError` when `include?` gets anything but a module (see
[Looking up members](#looking-up-members)):

```ruby
# When trying to add a new member to a frozen enum
Color.send(:new)
#=> Shy::Enum::Error "Can't add new values to a closed Enum"

# When trying to set a HasEnum attribute (see below) to an object that isn't a member
flower.color = "red"
#=> Shy::Enum::Error "Type error. Enum type must be a Color"

# When trying to add a member with a duplicated value
class Status < Shy::Enum::Base
  Draft = new(0)
  Deleted = new(0)
  #=> Shy::Enum::Error "Duplicated member"
end

# When trying to fetch a non-existent enum member
Color.fetch("brown")
#=> Shy::Enum::Error "Unknown member for value \"brown\""

# When trying to modify a frozen enum member
Color::Red.value = "new_value"
#=> FrozenError "can't modify frozen Color: #<Color::Red value=\"red\">"
```

The Rails integrations raise their own errors too, see [ActiveModel](RAILS.md#activemodel) and
[ActiveRecord](RAILS.md#activerecord).

### Freezing

Members are always frozen as soon as their constant is defined. The enum class is not:
you freeze it yourself by calling `freeze` after the last member. Until then the enum
is open and can still gain members: any member assigned to a new constant joins it, e.g.
`Color.const_set(:Black, Color.send(:new))`. A member not assigned to a constant is not added.

```ruby
class Color < Shy::Enum::Base
  Red = new

  freeze # closes the enum
end

Color.send(:new) # raises: Can't add new values to a closed Enum (Shy::Enum::Error)
```

Always end the enum with `freeze`: it keeps the set of members fixed. Once frozen, the class
can't be changed any more, so define everything you need, such as `before_cast`, before it.

Freezing also makes `all` (and `registry`) and `values` cheaper: a frozen enum builds their
Arrays once and returns the same frozen Arrays on every call, while an open enum builds new
ones each time. Lookups (`[]`, `fetch`, `member?`), `each` and `size` allocate nothing either way.
Objects allocated per call on an enum with 20 members:

| Call      | Open | Frozen |
|-----------|-----:|-------:|
| `all`     |    1 |      0 |
| `values`  |    1 |      0 |
| `[]`      |    0 |      0 |
| `each {}` |    0 |      0 |

The Arrays returned by a frozen enum are frozen: `Color.all << x` raises `FrozenError`. Call
`dup` on them if you need to change them.

## HasEnum

`Shy::Enum::HasEnum` plugs an enum into any class, so its instances can hold one of the
members. It is loaded together with the gem: `require "shy/enum"` is enough.

Include the module and declare the enum with `enum`:

```ruby
class Flower
  include Shy::Enum::HasEnum

  enum Color
end

flower = Flower.new
flower.color #=> nil
flower.pink!
flower.color #=> #<Color::Pink value="pink">
flower.pink? #=> true
flower.violet? #=> false
flower.color = Color::Red
flower.color #=> #<Color::Red value="red">
```

`enum` defines these methods on the class:
- a reader and a writer named after the enum, downcased and without its namespace
  (`color` and `color=` for `Color`, `state` for `Issue::State`)
- a predicate `value?` and a setter `value!` for each member, named after its value
  (`pink?` and `pink!`)

The values must make valid method names: with Integer values the predicates and setters are
named e.g. `0?` and `0!`, and can only be called with `send`. [`shy_enum`](RAILS.md#activerecord) names
them after the member name instead.

To pick another name for the reader and the writer, pass `as:` (a Symbol or a String).
Predicates and setters are not affected:

```ruby
class Flower
  include Shy::Enum::HasEnum

  enum Color, as: :petals
end

flower = Flower.new
flower.petals = Color::Red
flower.petals #=> #<Color::Red value="red">
flower.red? #=> true
```

The writer only accepts members of that enum. Anything else, including a matching value,
raises `Shy::Enum::Error`:

```ruby
flower.color = "red" #=> Shy::Enum::Error "Type error. Enum type must be a Color"
```

## Rails

Opt-in integrations for Rails ~> 8.1, documented in [RAILS.md](RAILS.md):

- [ActiveModel](RAILS.md#activemodel) - an `ActiveModel::Type` for enum attributes
- [ActiveRecord](RAILS.md#activerecord) - the `shy_enum` macro, modeled on Rails' `enum`

## Installation

It requires Ruby 4.0 or later. Install the gem and add to the application's Gemfile by executing:

    $ bundle add shy-enum --github "alessandro-fazzi/shy-enum"

Then require it:

```ruby
require "shy/enum"
```

The Rails integrations are opt-in and need activemodel or activerecord ~> 8.1 in your bundle:
`require "shy/enum/active_model"` or `require "shy/enum/active_record"`. See [Rails](#rails).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake` to run all the
suites and RuboCop. There are three test suites, each in its own process: `rake test` (core, no Rails
loaded), `rake test:active_model` and `rake test:active_record`; `rake test:all` runs all three. The
ActiveRecord suite uses an in-memory SQLite database. You can also run `bin/console` for an interactive prompt that will allow
you to experiment.

Add `COVERAGE=1` to print a line and branch coverage report. A single suite reports only the files
it tests, from that run only; `COVERAGE=1 rake test:all` prints one report for all of `lib/`,
merging the three suites.

Run `bundle exec rake rdoc` to generate the API documentation from this README and the code comments
into `docs/`, then open `docs/index.html`. Run `bundle exec rake rerdoc` to rebuild it from scratch:
it deletes `docs/` first. The documentation is published to GitHub Pages by the `Deploy Docs` workflow.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version
number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git
commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/alessandro-fazzi/shy-enum. This project is
intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the
[code of conduct](https://github.com/alessandro-fazzi/shy-enum/blob/main/CODE_OF_CONDUCT.md).

## Acknowledgements

Shy::Enum draws ideas from [typesafe_enum](https://github.com/dmolesUC/typesafe_enum),
[ruby-enum](https://github.com/dblock/ruby-enum), [Literal](https://literal.fun/docs/enums.html)
and Python's [`enum`](https://docs.python.org/3/library/enum.html) module.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Shy::Enum project's codebases, issue trackers, chat rooms and mailing lists is expected to
follow the [code of conduct](https://github.com/alessandro-fazzi/shy-enum/blob/main/CODE_OF_CONDUCT.md).
