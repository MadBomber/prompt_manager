# frozen_string_literal: true

begin
  require "tocer/rake/register"
rescue LoadError => error
  puts error.message
end

Tocer::Rake::Register.call


require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test
