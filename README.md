# TraceSpy

TraceSpy is a wrapper around TracePoint to expose more power in matching against
various cases of Ruby and getting value from composable traces.

Right now this is super alpha and involves a lot of hackery, hence v0.0.1. I would
suggest reading into [Qo](https://github.com/baweaver/qo) to get an idea of how the matchers
work.

**WARNING**: When I say alpha, I mean no tests currently, and the API is going to likely
change quite a bit as I experiment with things. This is a proof-of-concept to see how
I can create a nice API, and we'll work from there.

## Usage

The methods themselves are documented, and I'll work on expanding this section later with more examples and ideas
as I can.

```ruby
def testing(a, b, c)
  raise 'heck' if a.is_a?(Numeric) && a > 20

  d = 5 if c.is_a?(Numeric) && c > 3

  a + b + c
end

testing_spy = TraceSpy::Method.new(:testing) do |spy|
  # On the arguments, given as keywords, will yield arguments to the block
  spy.on_arguments do |m|
    m.when(a: String, b: String, c: String) do |v|
      puts "Oh hey! You called me with strings: #{v}"
    end

    m.when(a: 1, b: 2, c: 3) do |v|
      puts "My args were 1, 2, 3: #{v}"
    end
  end

  # On an exception, will yield exception to the block
  spy.on_exception do |m|
    m.when(RuntimeError) do |e|
      puts "I encountered an error: #{e}"
    end
  end

  # On a return value, will yield the return to the block
  spy.on_return do |m|
    m.when(String) do |v|
      puts "Strings in, Strings out no?: #{v}. I got this in though: #{spy.current_arguments}"
    end

    m.when(:even?) do |v|
      puts "I got an even return: #{v}"
    end
  end

  # On a local variable being present:
  spy.on_locals do |m|
    m.when(d: 5) do |v|
      puts "I saw d was a local in here!: #{v}. I could also ask this: #{spy.current_local_variables}"
    end
  end
end

testing_spy.enable
# => false

p testing(1, 2, 3)
# My args were 1, 2, 3: {:a=>1, :b=>2, :c=>3}
# I got an even return: 6
# => 6

p testing(21, 2, 3) rescue 'nope'
# I encountered an error: heck
# => 'nope'

p testing(*%w(foo bar baz))
# Oh hey! You called me with strings: {:a=>"foo", :b=>"bar", :c=>"baz"}
# Strings in, Strings out no?: foobarbaz
# => 'foobarbaz'

p testing(1, 2, 4)
# I saw d was a local in here!: {:a=>1, :b=>2, :c=>4, :d=>5}
# => 7
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'trace_spy'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install trace_spy

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/baweaver/trace_spy. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the TraceSpy project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/baweaver/trace_spy/blob/master/CODE_OF_CONDUCT.md).
