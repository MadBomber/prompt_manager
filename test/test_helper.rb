# frozen_string_literal: true

# Coverage is measured on every run; the 100% line gate is enforced when the
# whole suite runs through `rake test` (which sets COVERAGE=1) or in CI, so a
# single test file can still be run on its own.
require 'simplecov'
SimpleCov.start do
  add_filter '/test/'
  enable_coverage :branch
  minimum_coverage line: 100 if ENV['COVERAGE'] == '1' || ENV.key?('CI')
end

require 'minitest/autorun'
require_relative '../lib/pm'

FIXTURES = File.expand_path('fixtures', __dir__)

def fixture(name)
  File.join(FIXTURES, name)
end
