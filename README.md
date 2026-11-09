# Shy::Enum

Shy::Enum is a small, dependency-free way to define enums in plain Ruby. Each member is a
frozen object with a name, a value and an ordinal position, so members are comparable, can be
looked up by value and carry extra attributes. A closed enum can't gain new members, and
[`HasEnum`](#hasenum) plugs an enum into any class with a reader, a writer and predicate methods.
Optional integrations for [ActiveModel](RAILS.md#activemodel) and
[ActiveRecord](RAILS.md#activerecord) are opt-in.

```ruby
class Color < Shy::Enum::Base
  Red = new
  Green = new
  Blue = new

  freeze
end

Color::Green         #=> #<Color::Green value="green">
Color::Green.name    #=> "Green"
Color::Green.value   #=> "green"
Color::Green.ordinal #=> 2
Color::Green.to_s    #=> "green"
```

Each member is a constant of the enum class. The ordinal is its position, starting from 1.
`freeze` closes the enum: always end it this way, see [Freezing](#freezing).

See [Installation](#installation) to add it to a project.

## Usage

The examples below share a few enums: `Color` from the top of this page, `Priority` and `Role`
from [Values](#values), `Currency` from [Extra attributes](#extra-attributes).

### Values

A member's value is its name, downcased, unless you pass one to `new`. Any object can be a
value, as long as it's unique within the enum:

```ruby
class Priority < Shy::Enum::Base
  Low = new(0)
  Medium = new(1)
  High = new(2)

  freeze
end

class Role < Shy::Enum::Base
  Admin = new("administrator")
  User = new("regular_user")
  Guest = new

  freeze
end

Color::Red.value     #=> "red"
Priority::High.value #=> 2
Role::Admin.value    #=> "administrator"
Role::Guest.value    #=> "guest"
```

`to_s` always returns the value as a String: `Priority::High.to_s #=> "2"`.

### Extra attributes

Keyword arguments passed to `new` become attributes with a reader, like a Struct.
Members without an attribute return `nil`; the value stays the positional argument.

```ruby
class Currency < Shy::Enum::Base
  Euro = new("EUR", symbol: "€", decimals: 2)
  Yen = new("JPY", symbol: "¥", decimals: 0)
  Bitcoin = new("BTC")

  freeze
end

Currency::Euro.value      #=> "EUR"
Currency::Euro.symbol     #=> "€"
Currency::Yen.decimals    #=> 0
Currency::Bitcoin.symbol  #=> nil
```

An attribute can't override an existing method, e.g. `new(name: "foo")` raises `Shy::Enum::Error`:

```ruby
class Currency < Shy::Enum::Base
  Euro = new(name: "foo")
  #=> Shy::Enum::Error "`name` is a reserved method and can't be overridden by an attribute reader"
end
```

### After initialize

Override `after_initialize` to refine a member right after it is built, e.g. to derive
extra state from its attributes. There's no need to call `super` or to override `initialize`.

```ruby
class Size < Shy::Enum::Base
  attr_reader :label

  def after_initialize
    @label = "#{width}x#{height}"
  end

  Small = new(width: 640, height: 480)
  Large = new(width: 1920, height: 1080)

  freeze
end

Size::Large.label #=> "1920x1080"
```

The [extra attributes](#extra-attributes) are already set and so are the positional
value, when given, and the ordinal. The `name` is not: it's assigned when the constant is
defined, and so is the default value. The member is also still unfrozen, so it can be
modified here.

> [!IMPORTANT]
> Define `after_initialize` before the members, as in the example: it runs
> while each member is being built, so members declared above it won't call it.

### Inspecting members

`inspect` shows the value and the instance variables of the member, mimicking `Data`.
Each [extra attribute](#extra-attributes) is stored in an instance variable of the same
name (`symbol` in `@symbol`), which is why it shows up here:

```ruby
Currency::Euro.inspect    #=> #<Currency::Euro value="EUR", symbol="€", decimals=2>
Currency::Bitcoin.inspect #=> #<Currency::Bitcoin value="BTC">
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

### Comparing members

Members compare by ordinal, that is in declaration order:

```ruby
Priority::Low < Priority::High          #=> true
Priority::High <=> Priority::Medium     #=> 1
Priority::Low == Priority::Low          #=> true
Priority::Low.between?(Priority::Low, Priority::Medium) #=> true
```

Members are only comparable with members of the same enum: with any other object
`<=>` returns `nil` and `==` returns `false`, values included:

```ruby
Priority::Low <=> 0 #=> nil
Priority::Low == 0  #=> false
```

### Using in case statements

A member matches itself in a `case`, through `===`:

```ruby
case priority
when Priority::High then page_someone
when Priority::Medium, Priority::Low then open_ticket
end
```

### Iterating members

The enum class is `Enumerable` over its members, in declaration order:

```ruby
Color.each { puts it.name } # prints Red, Green, Blue
Color.map(&:value)          #=> ["red", "green", "blue"]
Color.size                  #=> 3
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

Use `fetch` where data from outside enters your code, e.g. a JSON payload, and pass the member
around from there: invalid input fails right away instead of travelling as a String. An attribute
that casts, such as [`shy_enum`](RAILS.md#assigning-values), does the lookup for you.

Values are compared strictly: `Priority["1"]` and `Priority[1.0]` don't find the member whose
value is `1`. To convert the input before the lookup, override the private `before_cast` class
method. Here's `Priority` again, with `before_cast`:

```ruby
class Priority < Shy::Enum::Base
  Low = new(0)
  Medium = new(1)
  High = new(2)

  def self.before_cast(obj) = Integer(obj, exception: false)
  private_class_method :before_cast

  freeze
end

Priority["1"] #=> #<Priority::Medium value=1>
```

That's what you need for values coming from request params, which are always Strings: the
Rails guide shows the whole round trip in
[Integer values from params](RAILS.md#integer-values-from-params).

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

### Custom methods

Members are plain Ruby objects, so you can add your own methods to the enum, on the
members and on the class itself. Comparison and `Enumerable` make a state machine
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
IssueState.working.map(&:value) #=> ["in_progress", "review"]
```

### Freezing

Members are always frozen as soon as their constant is defined. The enum class is not:
you freeze it yourself by calling `freeze` after the last member. Until then the enum
is open and can still gain members: any member assigned to a new constant joins it, e.g.
`Color.const_set(:Black, Color.send(:new))`. A member not assigned to a constant is not added.

```ruby
Color.send(:new) # raises: Can't add new values to a closed Enum (Shy::Enum::Error)
```

Always end the enum with `freeze`: it keeps the set of members fixed. Once frozen, the class
can't be changed any more, so define everything else, such as methods and `before_cast`,
before it. Freezing also makes `all` and `values` cheaper: they return the same frozen Array
on every call.

### Exceptions

Errors raised by the library are instances of `Shy::Enum::Error`, except for `FrozenError`
when modifying a member and `TypeError` when `include?` gets anything but a module (see
[Looking up members](#looking-up-members)):

```ruby
# When trying to add a new member to a frozen enum
Color.send(:new)
#=> Shy::Enum::Error "Can't add new values to a closed Enum"

# When trying to add a member with a duplicated value
class Answer < Shy::Enum::Base
  Yes = new(1)
  Ok = new(1)
  #=> Shy::Enum::Error "Duplicated member"
end

# When trying to fetch a non-existent enum member
Color.fetch("brown")
#=> Shy::Enum::Error "Unknown member for value \"brown\""

# When trying to modify a frozen enum member
Color::Red.value = "new_value"
#=> FrozenError "can't modify frozen Color: #<Color::Red value=\"red\">"
```

[HasEnum](#hasenum) and the Rails integrations raise their own errors too, see their sections.

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
flower.green!
flower.color #=> #<Color::Green value="green">
flower.green? #=> true
flower.red? #=> false
flower.color = Color::Red
flower.color #=> #<Color::Red value="red">
```

`enum` defines these methods on the class:
- a reader and a writer named after the enum, downcased and without its namespace
  (`color` and `color=` for `Color`, `state` for `Issue::State`)
- a predicate `value?` and a setter `value!` for each member, named after its value
  (`green?` and `green!`)

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

Opt-in integrations for ActiveModel and ActiveRecord. With ActiveRecord, `shy_enum` stores
the member's value in a column and reads the member back, with scopes and predicates modeled
on Rails' `enum`:

```ruby
class Post < ApplicationRecord
  include Shy::Enum::ActiveRecordEnum

  shy_enum :priority, Priority # integer column
end

post = Post.create!(priority: Priority::High)
post.priority #=> #<Priority::High value=2>
post.high?    #=> true
Post.low      # scope
```

ActiveModel gets an attribute type, `:shy_enum`, for form objects and other models without
a table. The [Rails guide](RAILS.md) covers both: forms, validation, querying and how
`shy_enum` differs from Rails' `enum`.

## Installation

It requires Ruby 4.0 or later. Install the gem and add to the application's Gemfile by executing:

    $ bundle add shy-enum --github "alessandro-fazzi/shy-enum"

Then require it:

```ruby
require "shy/enum"
```

The Rails integrations are opt-in and need activemodel or activerecord in your bundle:
`require "shy/enum/active_model"` or `require "shy/enum/active_record"`. See [Rails](#rails).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake` to run all the
suites and RuboCop. There are three test suites, each in its own process: `rake test` (core, no Rails
loaded), `rake test:active_model` and `rake test:active_record`; `rake test:all` runs all three. The
ActiveRecord suite uses an in-memory SQLite database. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

Add `COVERAGE=1` to print a line and branch coverage report. A single suite reports only the files
it tests, from that run only; `COVERAGE=1 rake test:all` prints one report for all of `lib/`,
merging the three suites.

Run `bundle exec rake rdoc` to generate the documentation into `docs/`, then open
`docs/index.html`. Run `bundle exec rake rerdoc` to rebuild it from scratch: it deletes `docs/`
first. The documentation is published to GitHub Pages by the `Deploy Docs` workflow.

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
