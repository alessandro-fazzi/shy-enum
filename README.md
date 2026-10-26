> [!WARNING]
> This is a POC built to support a discussion between colleagues.
> It's born unmaintained by its own nature.

# Shy::Enum

Studying [typesafe_enum](https://github.com/dmolesUC/typesafe_enum/tree/master) and
[ruby_enum](https://github.com/dblock/ruby-enum) and [literal](https://literal.fun/docs/enums.html)

```ruby
class Color < Shy::Enum::Base
  PINK = new
  RED = new
  VIOLET = new

  freeze
end

class Flower
  include Shy::Enum::HasEnum

  enum Color
end

flower = Flower.new
flower.color #=> nil
flower.pink!
flower.color #=> #<Color::PINK value="pink">
flower.pink? #=> true
flower.violet? #=> false
flower.color = Color::RED
flower.color #=> #<Color::RED value="red">

Color.send(:new, :BROWN) # raises: Can't add new values to a closed Enum (Shy::Enum::Error)
```

### Setting integer values

```ruby
class Status < Shy::Enum::Base
  DRAFT = new(0)
  PUBLISHED = new(1)
  ARCHIVED = new(2)

  freeze
end

Status::DRAFT.value #=> 0
Status::PUBLISHED.value #=> 1
Status::ARCHIVED.value #=> 2
```

### Setting string values

```ruby
class Role < Shy::Enum::Base
  ADMIN = new("administrator")
  USER = new("regular_user")
  GUEST = new("guest")

  freeze
end

Role::ADMIN.value #=> "administrator"
Role::USER.value #=> "regular_user"
Role::GUEST.value #=> "guest"
```

### Extra attributes

Keyword arguments passed to `new` become attributes with a reader, like a Struct.
Members without an attribute return `nil`; the value stays the positional argument.

```ruby
class Color < Shy::Enum::Base
  RED = new(hex: "ff0000")
  GREEN = new("verde", hex: "00ff00")
  BLUE = new

  freeze
end

Color::RED.hex      #=> "ff0000"
Color::GREEN.value  #=> "verde"
Color::BLUE.hex     #=> nil
```

Attributes are already set when `after_initialize` runs. An attribute can't override
an existing method, e.g. `new(name: "foo")` raises `Shy::Enum::Error`.

### Inspecting members

`inspect` shows the value and the instance variables of the member, like `Data`:

```ruby
Color::RED.inspect   #=> #<Color::RED value="red", hex="ff0000">
Color::BLUE.inspect  #=> #<Color::BLUE value="blue">
```

To choose what to show, override the private `instance_variables_to_inspect`:

```ruby
class ApiKey < Shy::Enum::Base
  PUBLIC = new(token: "abc")

  private

  def instance_variables_to_inspect = %i[@value]

  freeze
end

ApiKey::PUBLIC.inspect #=> #<ApiKey::PUBLIC value="public">
```

### Default values

```ruby
class Color < Shy::Enum::Base
  RED = new       # value is automatically set to "red"
  GREEN = new     # value is automatically set to "green"
  BLUE = new      # value is automatically set to "blue"

  freeze
end

Color::RED.value #=> "red"
Color::GREEN.value #=> "green"
Color::BLUE.value #=> "blue"
```

### Comparing enum members

The comparison is based on the enum member's ordinal position, which is assigned in declaration order.

```ruby
class Status < Shy::Enum::Base
  DRAFT = new
  PUBLISHED = new
  ARCHIVED = new

  freeze
end

Status::DRAFT < Status::PUBLISHED    #=> true
Status::PUBLISHED > Status::DRAFT    #=> true
Status::ARCHIVED > Status::PUBLISHED #=> true
Status::DRAFT < Status::ARCHIVED    #=> true
```

### Using in case statements

Enum members can be used in case statements thanks to Ruby's `===` operator. Here's how it works:

```ruby
class Status < Shy::Enum::Base
  DRAFT = new
  PUBLISHED = new
  ARCHIVED = new
  freeze
end

status = Status::PUBLISHED

# Ruby uses === internally for case statements
# This is equivalent to Status::DRAFT === status
case status
when Status::DRAFT
  puts "Still working on it"
when Status::PUBLISHED
  puts "Live and ready"
when Status::ARCHIVED
  puts "No longer active"
end
#=> "Live and ready"

# You can also use it directly
Status::PUBLISHED === status #=> true
Status::DRAFT === status    #=> false
```

### Iterating members

The enum class is `Enumerable` over its members, in declaration order.

```ruby
Color.each { puts it.name }    # prints PINK, RED, VIOLET
Color.map(&:value)             #=> ["pink", "red", "violet"]
Color.size                     #=> 3
Color.member?(Color::RED)      #=> true
Color.member?("red")           #=> true
Color.member?("brown")         #=> false
```

`member?` checks members and values like `[]` does. `include?` keeps its `Module`
meaning (included modules) and raises `TypeError` when given anything else.

### Looking up members

`[]` finds a member by member or by value and returns `nil` when nothing matches.
`fetch` (aliased as `cast`) does the same, but raises `Shy::Enum::Error`.

```ruby
Color["red"]          #=> Color::RED
Color[Color::RED]     #=> Color::RED
Color["brown"]        #=> nil
Color.fetch("red")    #=> Color::RED
Color.cast("brown")   # raises: Unknown member for value "brown" (Shy::Enum::Error)
```

Values are compared strictly, so `Status["1"]` doesn't find a member whose value is `1`.
To convert the input before the lookup, e.g. strings coming from request params,
override the private `before_cast` class method. Define it before calling `freeze`:

```ruby
class Status < Shy::Enum::Base
  DRAFT = new(0)
  PUBLISHED = new(1)

  def self.before_cast(obj) = Integer(obj, exception: false)
  private_class_method :before_cast

  freeze
end

Status["1"] #=> Status::PUBLISHED
```

### Exceptions

The following exceptions could be raised:

```ruby
# When trying to add a new member to a frozen enum
Color.send(:new, :BROWN)
#=> Shy::Enum::Error "Can't add new values to a closed Enum"

# When trying to set an enum value with an instance of a different class
flower.color = String.new("red")
#=> Shy::Enum::Error "Type error. Enum type must be of the same class"

# When trying to add a member with a duplicated value
class Status < Shy::Enum::Base
  DRAFT = new(0)
  DELETED = new(0)
  #=> Shy::Enum::Error "Duplicated member"
end

# When trying to fetch a non-existent enum member
Color.fetch("brown")
#=> Shy::Enum::Error "Unknown member for value \"brown\""

# When trying to modify a frozen enum member
Color::RED.instance_variable_set(:@value, "new_value")
#=> FrozenError "can't modify frozen ...""
```

## Installation

> [!NOTE]
> This gem is not and will not be published on rubygems since it's just a POC

Install the gem and add to the application's Gemfile by executing:

    $ bundle add shy-interactor --github "alessandro-fazzi/shy-enum"

## Usage

[test/shy/test_base.rb](test/shy/test_base.rb)
[test/shy/test_has_enum.rb](test/shy/test_has_enum.rb)
[test/test_helper.rb](test/test_helper.rb)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

Run `COVERAGE=1 rake test` to also print a line and branch coverage report after the test suite runs.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/alessandro-fazzi/shy-enum. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/alessandro-fazzi/shy-enum/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Shy::Enum project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/alessandro-fazzi/shy-enum/blob/main/CODE_OF_CONDUCT.md).
