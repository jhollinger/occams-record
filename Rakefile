require 'bundler/setup'
require 'rake/testtask'

desc "Run performance benchmarks"
task :bench do
  require_relative './bench/seeds'
  require_relative './bench/occams_bench'
  $:.unshift File.join(File.dirname(__FILE__), "lib")
  require 'occams-record'

  puts OccamsBench.new("belongs_to (many to one)").
    measure("ActiveRecord") {
      Widget.all.preload(:category).find_each(batch_size: 1000) { |w|
        w.name
      }
    }.
    measure("OccamsRecord") {
      OccamsRecord.
        query(Widget.all).
        eager_load(:category).
        find_each(batch_size: 1000) { |w|
          w.name
        }
    }.
    run

  puts OccamsBench.new("belongs_to (one to one)").
    measure("ActiveRecord") {
      WidgetDetail.all.preload(:widget).find_each(batch_size: 1000) { |d|
        d.widget.name
      }
    }.
    measure("OccamsRecord") {
      OccamsRecord.
        query(WidgetDetail.all).
        eager_load(:widget).
        find_each(batch_size: 1000) { |w|
          w.widget.name
        }
    }.
    run

  puts OccamsBench.new("has_one (one to one)").
    measure("ActiveRecord") {
      Widget.all.preload(:detail).find_each(batch_size: 1000) { |w|
        w.detail.text
      }
    }.
    measure("OccamsRecord") {
      OccamsRecord.
        query(Widget.all).
        eager_load(:detail).
        find_each(batch_size: 1000) { |w|
          w.detail.text
        }
    }.
    run

  puts OccamsBench.new("has_many").
    measure("ActiveRecord") {
      Category.all.preload(:widgets).each { |cat|
        cat.widgets.size
      }
    }.
    measure("OccamsRecord") {
      OccamsRecord.
        query(Category.all).
        eager_load(:widgets).
        each { |cat|
          cat.widgets.size
        }
    }.
    run
end

Rake::TestTask.new do |t|
  t.libs << 'lib' << 'test'
  t.test_files = FileList['test/**/*_test.rb']
  t.verbose = false
end
