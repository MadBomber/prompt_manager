# Loaded by `irb` when started from the repo root.
# Gives you PM with the test fixtures as the prompts directory, e.g.
#   PM.parse(:simple).to_s
require_relative 'lib/pm'

PM.configure { |c| c.prompts_dir = File.join(__dir__, 'test', 'fixtures') }
