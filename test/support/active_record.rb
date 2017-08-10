require 'otr-activerecord'
require 'active_record/fixtures'
ActiveRecord::Base.logger = nil

OTR::ActiveRecord.configure_from_hash!(adapter: 'sqlite3', database: ':memory:', encoding: 'utf8', pool: 5, timeout: 5000)

ActiveRecord::Base.connection.instance_eval do
  create_table :categories do |t|
    t.string :name, null: false
  end

  create_table :widgets do |t|
    t.string :name, null: false
    t.integer :category_id
  end

  create_table :widget_details do |t|
    t.integer :widget_id
    t.text :text
  end

  create_table :customers do |t|
    t.string :name
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

class Category < ActiveRecord::Base
end

class Widget < ActiveRecord::Base
  belongs_to :category
  has_one :detail, class_name: 'WidgetDetail'
end

class WidgetDetail < ActiveRecord::Base
  belongs_to :widget
end

class Customer < ActiveRecord::Base
end

class Order < ActiveRecord::Base
  belongs_to :customer
  has_many :items, class_name: 'OrderItem'
end

class OrderItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :widget
end
