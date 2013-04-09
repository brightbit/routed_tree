require 'minitest/spec'
require 'minitest/autorun'
require 'minitest-matchers'
require 'pry'

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require f }
