require_relative '../test/support/active_record'
require_relative './multi_inserter'

MultiInserter.new("categories", %w(name)).
  insert!(*("A".."Z").map { |x| [x] })
cat_ids = Category.all.pluck(:id)

MultiInserter.new("widgets", %w(name category_id)).tap { |inserter|
  (1..100_000).each_slice(2000) { |slice|
    inserter.insert!(*slice.map { |i|
      ["Widget #{i}", cat_ids.sample]
    })
  }
}

MultiInserter.new("widget_details", %w(widget_id text)).tap { |inserter|
  Widget.all.pluck(:id).each_slice(2000) { |slice|
    inserter.insert!(*slice.map { |id|
      [id, "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."]
    })
  }
}

MultiInserter.new("splines", %w(name category_id)).tap { |inserter|
  (1..100_000).each_slice(2000) { |slice|
    inserter.insert!(*slice.map { |i|
      ["Spline #{i}", cat_ids.sample]
    })
  }
}

