# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'routed_tree/version'

Gem::Specification.new do |spec|
  spec.name          = "routed_tree"
  spec.version       = RoutedTree::VERSION
  spec.authors       = ["Jonathan Camenisch"]
  spec.email         = ["jonathan@camenisch.net"]
  spec.description   = %q{A wrapper for trees (nested hashes and/or arrays of hashes and/or arrays) } +
                       %q{that lets you reorganize access to underlying data with "routing" rules}
  spec.summary       = %q{A tree structure with "routes"}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  # spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "json"

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest", "~> 4.4"
  spec.add_development_dependency "minitest-matchers"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-doc"
  spec.add_development_dependency "pry-stack_explorer"
  spec.add_development_dependency "pry-debugger"
end
