# frozen_string_literal: true

# Coverage is measured on every run; the 100% line and branch gates are
# enforced when the whole suite runs through `rake test` (which sets
# COVERAGE=1) or in CI (where CI is literally "true"), so a single test file
# can still be run on its own.
require 'simplecov'
SimpleCov.start do
  skip '/test/'
  enable_coverage :branch
  minimum_coverage line: 100, branch: 100 if ENV['COVERAGE'] == '1' || ENV['CI'] == 'true'
end

require 'minitest/autorun'
require_relative '../lib/pm'

FIXTURES = File.expand_path('fixtures', __dir__)

def fixture(name)
  File.join(FIXTURES, name)
end

# Set the given ENV vars for the duration of the block, then restore each key
# to exactly what it was before — including "was previously unset". Use a nil
# value to delete a key for the block. Prefer this over bare ENV.delete in an
# ensure, which clobbers any preexisting value a developer had set.
WITH_ENV_UNSET = Object.new.freeze

def with_env(vars)
  saved = vars.keys.to_h { |key| [key, ENV.key?(key) ? ENV[key] : WITH_ENV_UNSET] }
  vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  yield
ensure
  saved.each { |key, value| value.equal?(WITH_ENV_UNSET) ? ENV.delete(key) : ENV[key] = value }
end
