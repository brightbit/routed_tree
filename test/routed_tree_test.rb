require_relative 'test_helper'
require 'routed_tree'

# Reverse environment configuration
RoutedTree.config do
  def key_transform(k);   k; end
  def key_untransform(k); k; end
end

describe RoutedTree do
  before do
    @routree = RoutedTree[
      one: 1,
      two: 2,
      three: 3,
      hash_one: { a: :A, b: :B },
      array_one: [:a, :b, :c],
      deeper_hash: {
        hash_two: { c: :C, d: :D },
        array_two: [:d, :e, :f],
      },
      deeper_array: [
        { c: :C, d: :D },
        [:d, :e, :f]
      ]
    ]
  end

  it "Provides access to hash contents" do
    @routree[:one].must_equal   1
    @routree[:two].must_equal   2
    @routree[:three].must_equal 3
  end

  it "Wraps member hashes in routable hashes"  do
    @routree[:hash_one].class.must_equal RoutedTree
    @routree[:deeper_array][0].class.must_equal RoutedTree
  end

  it "Wraps member arrays in routable hashes" do
    @routree[:array_one].class.must_equal RoutedTree
    @routree[:deeper_array][1].class.must_equal RoutedTree
  end

  it "provides access to array elements" do
    @routree[:array_one][0].must_equal :a
  end

  it "knows what 'route' it came from" do
    @routree.full_route.must_equal []
    @routree[:deeper_hash][:hash_two].full_route.must_equal  [:deeper_hash, :hash_two]
    @routree[:deeper_hash][:array_two].full_route.must_equal [:deeper_hash, :array_two]
    @routree[:deeper_array][0].full_route.must_equal [:deeper_array, 0]
  end

  it "allows multi-key subscripts" do
    @routree[:deeper_hash, :array_two, 0].must_be_same_as @routree[:deeper_hash][:array_two][0]
  end

  it "memoizes everything" do
    @routree[:hash_one].must_be_same_as @routree[:hash_one]
    @routree[:deeper_hash][:array_two].must_be_same_as @routree[:deeper_hash][:array_two]
  end

  it "knows it's parent" do
    @routree[:hash_one].parent.must_be_same_as @routree
    @routree[:deeper_hash][:array_two].parent.must_be_same_as @routree[:deeper_hash]
  end

  it "implements Enumerable on arrays" do
    @routree[:array_one].map(&:to_s).must_equal %w(a b c)
  end

  it "implements Enumerable on hashes" do
    @routree[:hash_one].map{ |k, v| "#{k}:#{v}" }.must_equal %w(a:A b:B)
  end

  it "wraps members in RoutedTree when iterating" do
    @routree[:deeper_hash].map{ |_, v| v.class }.must_equal [RoutedTree, RoutedTree]
    @routree[:deeper_array].map(&:class).must_equal [RoutedTree, RoutedTree]
  end

  it "wraps members in RoutedTree via Enumerable convenience methods" do
    @routree[:deeper_array].first.class.must_equal RoutedTree
    @routree[:deeper_array].find{ |e| e.class == RoutedTree }[:c].must_equal :C
  end

  describe "basic route configuration" do
    class CustomRoutedTree3 < RoutedTree
    end

    class CustomRoutedTree2 < RoutedTree
      router.config do
        map 'subbranch3' => CustomRoutedTree3
      end
    end

    class CustomRoutedTree1 < RoutedTree
      router.config do
        map 'branch_1/subbranch2' => CustomRoutedTree2
        map 'custom_class/symbol_route' => :symbol_key_hash,                       class: CustomRoutedTree2
        map 'custom_class/alias_route' => ['non/existent', 'branch_1/subbranch2'], class: CustomRoutedTree2
        map('lambda') { 'results' }
        map('deeper/lambda') { 'deeper' }
        map 'symbol_key' => :symbol_key
        map 'deeper/symbol_key' => :symbol_key_deeper
        map 'hash/symbol_key' => :symbol_key_hash
        map 'array/symbol_key' => :symbol_key_array
        map 'branch_1/virtual' => 'branch_1/subbranch2'
        map 'branch_1/virtual2' => ['branch_1/subbranch2', 'branch_1/array_two/0']
        map 'branch_1/virtual3' => ['branch_1/nonexistent', 'branch_1/subbranch2/subbranch3']
        map 'branch_1/virtual4' => ['branch_1/non/existent', 'branch_1/subbranch2/subbranch3']
      end

      def symbol_key(*args)
        'symbol_key result'
      end

      def symbol_key_deeper(*args)
        'symbol_key_deeper result'
      end

      def symbol_key_hash(*args)
        {a: :A, b: :B}
      end

      def symbol_key_array(*args)
        [:x, :y, :z]
      end
    end

    before do
      @routree = CustomRoutedTree1[
        hash_one: { a: :A, b: :B },
        array_one: [:a, :b, :c],
        branch_1: {
          subbranch2: {
            c: :C, d: :D,
            subbranch3: [1, 2, 3]
          },
          array_two: [:d, :e, :f],
        },
        deeper_array: [
          { c: :C, d: :D },
          [:d, :e, :f]
        ]
      ]
    end

    it "knows what keys it contains (including virtual ones)" do
      @routree.keys.sort.uniq.must_equal [
        :hash_one, :array_one, :branch_1, :deeper_array, :lambda,
        :deeper, :symbol_key, :hash, :array, :custom_class
      ].sort
    end

    it "doesn't return :_ among keys" do
      @routree[:branch_1][:virtual].keys.sort.must_equal [:c, :d, :subbranch3]
    end

    it "wraps members in configured custom class" do
      branch = @routree[:branch_1][:subbranch2]
      branch.class.must_equal CustomRoutedTree2
      branch[:c].must_equal :C
    end

    it "wraps sub-members in configured custom class" do
      branch = @routree[:branch_1][:subbranch2][:subbranch3]
      branch.class.must_equal CustomRoutedTree3
      branch.first.must_equal 1
    end

    it "implements Enumerable on arrays in subclasses" do
      @routree[:branch_1][:subbranch2][:subbranch3].map(&:to_s).must_equal %w(1 2 3)
    end

    it "implements Enumerable on hashes in subclasses" do
      @routree[:branch_1][:subbranch2].map{ |_, v| v.class }.last.must_equal CustomRoutedTree3
    end

    it "calls configured lambda for respective key" do
      @routree[:lambda].must_equal 'results'
    end

    it "calls configured lambda for nested key" do
      @routree[:deeper][:lambda].must_equal 'deeper'
    end

    it "calls method if symbol provided" do
      @routree[:symbol_key].must_equal 'symbol_key result'
      @routree[:deeper][:symbol_key].must_equal 'symbol_key_deeper result'
    end

    it "wraps hash results in RoutedTree for called method" do
      @routree[:hash][:symbol_key].class.must_equal CustomRoutedTree1
    end

    it "wraps array results in RoutedTree for called method" do
      @routree[:array][:symbol_key].class.must_equal CustomRoutedTree1
      @routree[:array][:symbol_key][1].must_equal :y
    end

    it "wraps array results in RoutedTree for called method" do
      @routree[:custom_class][:symbol_route].class.must_equal CustomRoutedTree2
      @routree[:custom_class][:symbol_route][:a].must_equal :A
    end

    it "returns aliased (as in, symlinked) content if string provided" do
      @routree[:branch_1][:virtual][:c].must_equal :C
    end


    it "returns first-map aliased content if array of strings provided" do
      @routree[:branch_1][:virtual2][:c].must_equal :C
    end

    it "returns first-map aliased content if array of strings provided" do
      @routree[:branch_1][:virtual3][0].must_equal 1
    end

    it "returns first-match aliased content after deep non-match" do
      @routree[:branch_1][:virtual4][0].must_equal 1
    end

    it "can wrap aliased content in custom class" do
      @routree[:custom_class][:alias_route].class.must_equal CustomRoutedTree2
      @routree[:custom_class][:alias_route][:c].must_equal :C
    end

    def expected_serialized_routree
      {
        custom_class: {
          alias_route: { c: :C, d: :D, subbranch3: [1, 2, 3] },
          symbol_route: { a: :A, b: :B, subbranch3: nil },
        },
        hash_one: { a: :A, b: :B },
        array_one: [:a, :b, :c],
        branch_1: {
          subbranch2: { c: :C, d: :D, subbranch3: [1, 2, 3] },
          array_two: [:d, :e, :f],
          virtual: { c: :C, d: :D, subbranch3: [1, 2, 3] },
          virtual2: { c: :C, d: :D, subbranch3: [1, 2, 3] },
          virtual3: [1, 2, 3],
          virtual4: [1, 2, 3]
        },
        deeper_array: [ { c: :C, d: :D }, [:d, :e, :f] ],
        lambda: 'results',
        deeper: { lambda: 'deeper', symbol_key: 'symbol_key_deeper result' },
        symbol_key: 'symbol_key result',
        hash: { symbol_key: { a: :A, b: :B } },
        array: { symbol_key: [ :x, :y, :z ] }
      }
    end

    it "knows how to serialize itself as a hash" do
      @routree.serializeable.must_match_hash expected_serialized_routree
    end

    it "knows how to serialize itself as json" do
      @routree.to_json.must_match_json JSON.dump(expected_serialized_routree)
    end
  end

  describe "key transformation" do
    class TransformingRoutedTree < RoutedTree
      def key_transform(key)
        key.to_s
           .sub(/^[a-z\d]*/) { $&.capitalize }
           .gsub(/(?:_|(\/))([a-z])?([a-z\d]*)/) { "#{$1}#{$2.upcase}#{$3}" }
           .gsub('/', '::')
      end

      def key_untransform(key)
        # borrowed from ActiveSupport #underscore implementation
        key.to_s.dup.tap do |ret|
          ret.gsub!(/::/, '/')
          ret.gsub!(/(?:([A-Za-z\d])|^)(zorg)(?=\b|[^a-z])/) { "#{$1}#{$1 && '_'}#{$2.downcase}" }
          ret.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
          ret.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
          ret.tr!("-", "_")
          ret.downcase!
        end.intern
      end
    end

    before do
      @routree = TransformingRoutedTree[
        'BranchOne' => {
          'SubBranch' => { 'A' => :a, 'B' => :b },
          'SubArray' => [:d, :e, :f],
        }
      ]
    end

    it "allows key transormation" do
      @routree[:branch_one][:sub_branch][:a].must_equal :a
      @routree[:branch_one][:sub_array][1].must_equal :e
    end

    it "untransforms keys as configured" do
      @routree[:branch_one].keys.must_equal [:sub_branch, :sub_array]
      @routree[:branch_one][:sub_branch].keys.must_equal [:a, :b]
    end
  end

  describe "monkey patching with config" do
    class CustomRoutedTree4 < RoutedTree
    end

    CustomRoutedTree4.config do
      def monkey_method
        'monkey say "hi"'
      end
    end

    it "allows defining methods within RoutredTree.config block" do
      CustomRoutedTree4[a: 'a'].monkey_method.must_equal 'monkey say "hi"'
    end
  end
end
