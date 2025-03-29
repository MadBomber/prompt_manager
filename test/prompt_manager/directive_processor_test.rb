# test/prompt_manager/directive_processor_test.rb

require 'test_helper'
require 'tempfile'

class DirectiveProcessorTest < Minitest::Test
  def setup
    @processor = PromptManager::DirectiveProcessor.new
  end

  def test_run_with_nil_or_empty
    assert_equal({}, @processor.run(nil))
    assert_equal({}, @processor.run({}))
  end

  def test_run_with_excluded_method
    directives = { "//run something" => "" }
    result = @processor.run(directives)
    expected = "Error: run is not a valid directive: //run something"
    assert_equal expected, result["//run something"]
  end

  def test_run_with_unknown_directive
    directives = { "//unknown parameter" => "" }
    result = @processor.run(directives)
    expected = "Error: Unknown directive '//unknown parameter'"
    assert_equal expected, result["//unknown parameter"]
  end

  def test_run_include_with_nonexistent_file
    directives = { "//include /path/to/nonexistent_file.txt" => "" }
    result = @processor.run(directives)
    expected = "Error: File '/path/to/nonexistent_file.txt' not accessible"
    assert_equal expected, result["//include /path/to/nonexistent_file.txt"]
  end

  def test_run_shell_with_fake_response
    # Override @shell with a fake shell that returns a predictable response.
    fake_shell = Object.new
    def fake_shell.execute(cmd)
      "executed: #{cmd}"
    end
    @processor.instance_variable_set(:@shell, fake_shell)

    directives = { "//shell echo hello" => "" }
    result = @processor.run(directives)
    expected = "executed: echo hello"
    assert_equal expected, result["//shell echo hello"]
  end

  def test_alias_import_for_include
    directives = { "//import /path/to/nonexistent_file.txt" => "" }
    result = @processor.run(directives)
    expected = "Error: File '/path/to/nonexistent_file.txt' not accessible"
    assert_equal expected, result["//import /path/to/nonexistent_file.txt"]
  end
end
