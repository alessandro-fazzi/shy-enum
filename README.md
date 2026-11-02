> [!WARNING]
> This is a POC built to support a discussion between colleagues.
> It's born unmaintained by its own nature.

# Shy::Enum

Studying [typesafe_enum](https://github.com/dmolesUC/typesafe_enum/tree/master) and
[ruby_enum](https://github.com/dblock/ruby-enum) and [literal](https://literal.fun/docs/enums.html)

```ruby
class Color < Shy::Enum::Base
  Pink = new
  Red = new
  Violet = new

  freeze
end

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

Color.send(:new, :Brown) # raises: Can't add new values to a closed Enum (Shy::Enum::Error)
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

### Setting string values

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

`to_s` always returns the value as a String:

```ruby
Status::Published.to_s #=> "1"
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

Color::Red.hex      #=> "ff0000"
Color::Green.value  #=> "verde"
Color::Blue.hex     #=> nil
```

Attributes are already set when `after_initialize` runs. An attribute can't override
an existing method, e.g. `new(name: "foo")` raises `Shy::Enum::Error`.

### Inspecting members

`inspect` shows the value and the instance variables of the member, like `Data`:

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
Status::Draft < Status::Archived    #=> true
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
#=> "Live and ready"

# You can also use it directly
Status::Published === status #=> true
Status::Draft === status    #=> false
```

### Iterating members

The enum class is `Enumerable` over its members, in declaration order.

```ruby
Color.each { puts it.name }    # prints Pink, Red, Violet
Color.map(&:value)             #=> ["pink", "red", "violet"]
Color.size                     #=> 3
Color.member?(Color::Red)      #=> true
Color.member?("red")           #=> true
Color.member?("brown")         #=> false
```

`member?` checks members and values like `[]` does. `include?` keeps its `Module`
meaning (included modules) and raises `TypeError` when given anything else.

### Looking up members

`[]` finds a member by member or by value and returns `nil` when nothing matches.
`fetch` (aliased as `cast`) does the same, but raises `Shy::Enum::Error`.

```ruby
Color["red"]          #=> Color::Red
Color[Color::Red]     #=> Color::Red
Color["brown"]        #=> nil
Color.fetch("red")    #=> Color::Red
Color.cast("brown")   # raises: Unknown member for value "brown" (Shy::Enum::Error)
```

Values are compared strictly, so `Status["1"]` doesn't find a member whose value is `1`.
To convert the input before the lookup, e.g. strings coming from request params,
override the private `before_cast` class method. Define it before calling `freeze`:

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

### Exceptions

The following exceptions could be raised:

```ruby
# When trying to add a new member to a frozen enum
Color.send(:new, :Brown)
#=> Shy::Enum::Error "Can't add new values to a closed Enum"

# When trying to set an enum value with an instance of a different class
flower.color = String.new("red")
#=> Shy::Enum::Error "Type error. Enum type must be of the same class"

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
Color::Red.instance_variable_set(:@value, "new_value")
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
