require 'minitest/spec'
require 'minitest/autorun'
require 'minitest-matchers'
require 'pry'

require 'pry-rescue/minitest' if ENV['PRY_RESCUE']

Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require f }
