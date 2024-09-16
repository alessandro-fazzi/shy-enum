> [!WARNING]
> This is a POC built to support a discussion between colleagues.
> It's born unmaintained by its own nature.

# Shy::Enum

This is just a **much** dumber implementation of [*typesafe_enum*](https://github.com/dmolesUC/typesafe_enum/tree/master)
written as POC and exercise after have studied *typesafe_enum* and
[*ruby_enum*](https://github.com/dblock/ruby-enum).

The only two things it adds to the table are

- `Shy::Enum::HasEnum` mixin used to add an enum to an object as an attribute.
- the `close!` class method which is just am expressive wrapper to `freeze` the
  enum class and error handling when adding more types to a closed enum.

```ruby
class Color < Shy::Enum::Base
  t :PINK
  t :RED
  t :VIOLET
  close!
end

class Flower
  extend Shy::Enum::HasEnum

  enum Color
end

flower = Flower.new
flower.color #=> nil
flower.pink!
flower.color #=> #<Color:0x000000011fcf84e0 @name=:PINK, @ord=1, @value="pink">
flower.pink? #=> true
flower.violet? #=> false
flower.color = Color::RED
flower.color #=> #<Color:0x00000001046a65a8 @name=:RED, @ord=2, @value="red">

Color.send(:t, :BROWN) # raises: Can't add new values to a closed Enum (Shy::Enum::Error)
```

## Installation

> [!NOTE]
> This gem is not and will not be published on rubygems since it's just a POC

Install the gem and add to the application's Gemfile by executing:

    $ bundle add shy-interactor --github "alessandro-fazzi/shy-enum"

## Usage

[test/shy/test_enum.rb](test/shy/test_enum.rb)
[test/test_helper.rb](test/test_helper.rb)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/shy-enum. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/shy-enum/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Shy::Enum project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/shy-enum/blob/main/CODE_OF_CONDUCT.md).
