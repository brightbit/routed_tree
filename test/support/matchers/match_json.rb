class MatchJson
  def initialize(json)
    @parsed_json = deep_sort_json(JSON.parse(json))
  end

  def deep_sort_json(input)
    case input
    when Hash
      input.keys.sort.inject({}) do |ret, k|
        ret[k] = deep_sort_json(input[k])
        ret
      end
    when Array
      input.map { |item| deep_sort_json(item) }
    else
      input
    end
  end

  def matches? subject
    @parsed_subject = deep_sort_json(JSON.parse(subject))
    @parsed_subject == @parsed_json
  end

  def failure_message_for_should
    "expected to match json\n\n" +
    "expected: #{JSON.dump @parsed_json}\n" +
    "actual: #{JSON.dump @parsed_subject}"
  end

  def failure_message_for_should_not
    "expected not to match json: #{@parsed_json}"
  end
end

MiniTest::Unit::TestCase.register_matcher MatchJson, :match_json
