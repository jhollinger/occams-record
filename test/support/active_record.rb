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

  create_table :splines do |t|
    t.string :name, null: false
    t.integer :category_id
  end

  create_table :customers do |t|
    t.string :name
  end

  create_table :orders do |t|
    t.date :date, null: false
    t.decimal :amount, precision: 10, scale: 2
    t.integer :customer_id
  end

  create_table :line_items do |t|
    t.integer :order_id, null: false
    t.integer :item_id
    t.string :item_type
    t.decimal :amount, precision: 10, scale: 2
  end

  create_table :users do |t|
    t.string :username
    t.timestamps null: false
  end

  create_table :offices do |t|
    t.string :name
  end

  create_table :offices_users, id: false do |t|
    t.integer :user_id, null: false
    t.integer :office_id, null: false
  end
end

class Category < ActiveRecord::Base
  has_many :widgets
  has_many :splines
end

class Widget < ActiveRecord::Base
  belongs_to :category
  has_one :detail, class_name: 'WidgetDetail'
  has_many :line_items, as: :item
end

class WidgetDetail < ActiveRecord::Base
  belongs_to :widget
end

class Spline < ActiveRecord::Base
  belongs_to :category
  has_many :line_items, as: :item
end

class Customer < ActiveRecord::Base
end

class Order < ActiveRecord::Base
  belongs_to :customer
  has_many :line_items
  has_many :ordered_line_items, -> { order("item_type") }, class_name: "LineItem"
end

class LineItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :item, polymorphic: true
end

class User < ActiveRecord::Base
  has_and_belongs_to_many :offices
end

class Office < ActiveRecord::Base
  has_and_belongs_to_many :users
end
