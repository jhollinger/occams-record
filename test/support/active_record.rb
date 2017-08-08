require 'otr-activerecord'
ActiveRecord::Base.logger = nil

OTR::ActiveRecord.configure_from_hash!(adapter: 'sqlite3', database: ':memory:', encoding: 'utf8', pool: 5, timeout: 5000)

ActiveRecord::Base.connection.instance_eval do
  create_table :widgets do |t|
    t.string :name, null: false
    t.integer :category_id
  end

  create_table :categories do |t|
    t.string :name, null: false
  end

  create_table :orders do |t|
    t.date :date, null: false
    t.decimal :amount, precision: 10, scale: 2
    t.integer :customer_id
  end

  create_table :order_items do |t|
    t.integer :order_id, null: false
    t.integer :widget_id
    t.decimal :amount, precision: 10, scale: 2
  end
end
