require_relative './occams_bench'

Benchmarks = [
  OccamsBench.new("simple query").
    active_record {
      Widget.all.find_each(batch_size: 1000) { |w| w.name }
    }.
    occams_record {
      OccamsRecord.
        query(Widget.all).
        find_each(batch_size: 1000) { |w| w.name }
    },

  OccamsBench.new("belongs_to (many to one)").
    active_record {
      Widget.all.preload(:category).find_each(batch_size: 1000) { |w|
        w.name
      }
    }.
    occams_record {
      OccamsRecord.
        query(Widget.all).
        eager_load(:category).
        find_each(batch_size: 1000) { |w|
          w.name
        }
    },

  OccamsBench.new("belongs_to (one to one)").
    active_record {
      WidgetDetail.all.preload(:widget).find_each(batch_size: 1000) { |d|
        d.widget.name
      }
    }.
    occams_record {
      OccamsRecord.
        query(WidgetDetail.all).
        eager_load(:widget).
        find_each(batch_size: 1000) { |w|
          w.widget.name
        }
    },

  OccamsBench.new("has_many").
    active_record {
      Category.all.preload(:widgets).each { |cat|
        cat.widgets.size
      }
    }.
    occams_record {
      OccamsRecord.
        query(Category.all).
        eager_load(:widgets).
        each { |cat|
          cat.widgets.size
        }
    },
]
