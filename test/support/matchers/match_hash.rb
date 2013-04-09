class MatchHash
  def initialize(hash)
    @hash = deep_sort_hash(hash)
  end

  def deep_sort_hash(input)
    case input
    when Hash
      input.keys.sort.inject({}) do |ret, k|
        ret[k] = deep_sort_hash(input[k])
        ret
      end
    when Array
      input.map { |item| deep_sort_hash(item) }
    else
      input
    end
  end

  def matches? subject
    @subject = deep_sort_hash(subject)
    @subject == @hash
  end

  def failure_message_for_should
    "expected to match hash\n\n" +
    "expected: #{@hash}\n" +
    "actual: #{@subject}"
  end

  def failure_message_for_should_not
    "expected not to match hash: #{@hash}"
  end
end

MiniTest::Unit::TestCase.register_matcher MatchHash, :match_hash
