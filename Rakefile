require 'bundler/setup'
require 'minitest/test_task'

desc "Run all benchmarks"
task :bench do
  Rake::Task["bench:speed"].invoke
  Rake::Task["bench:memory"].invoke
end

namespace :bench do
  desc "Run performance benchmarks"
  task :speed => :environment do
    puts "OccamsRecord Speed Test\n\n"
    Benchmarks.each do |benchmark|
      puts benchmark.speed
    end
  end

  desc "Run memory benchmarks"
  task :memory => :environment do
    puts "OccamsRecord Memory Test\n\n"
    Benchmarks.each do |benchmark|
      puts benchmark.memory
    end
  end

  task :environment do
    $:.unshift File.join(File.dirname(__FILE__), "lib")
    require 'occams-record'
    require_relative './bench/seeds'
    require_relative './bench/marks'
  end
end

# Accepts files, dirs, N=test_name_or/pattern/, X=test_name_or/pattern/
Minitest::TestTask.create(:test) do |t|
  globs = ARGV[1..].map { |a|
    if Dir.exist? a
      "#{a}/**/*_test.rb"
    elsif File.exist? a
      a
    end
  }.compact

  t.libs << "test" << "lib"
  t.test_globs = globs.any? ? globs : ["test/**/*_test.rb"]
end
