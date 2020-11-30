require 'otr-activerecord'
require 'active_record/fixtures'
ActiveRecord::Base.logger = nil

if ENV["TEST_DATABASE_URL"].to_s != ""
  OTR::ActiveRecord.configure_from_url!(ENV["TEST_DATABASE_URL"])
else
  OTR::ActiveRecord.configure_from_hash!(adapter: 'sqlite3', database: ':memory:', encoding: 'utf8', pool: 5, timeout: 5000)
end

ActiveRecord::Base.connection.instance_eval do
  drop_table :categories if table_exists? :categories
  create_table :categories do |t|
    t.string :type_code
    t.string :name, null: false
  end

  drop_table :category_types if table_exists? :category_types
  create_table :category_types do |t|
    t.string :code, null: false
    t.string :description, null: false
  end

  drop_table :widgets if table_exists? :widgets
  create_table :widgets do |t|
    t.string :name, null: false
    t.integer :category_id
  end
  add_index :widgets, :category_id

  drop_table :widget_details if table_exists? :widget_details
  create_table :widget_details do |t|
    t.integer :widget_id
    t.text :text
  end
  add_index :widget_details, :widget_id

  drop_table :splines if table_exists? :splines
  create_table :splines do |t|
    t.string :name, null: false
    t.integer :category_id
  end
  add_index :splines, :category_id

  drop_table :customers if table_exists? :customers
  create_table :customers do |t|
    t.string :name
  end

  drop_table :orders if table_exists? :orders
  create_table :orders do |t|
    t.date :date, null: false
    t.decimal :amount, precision: 10, scale: 2
    t.integer :customer_id
  end
  add_index :orders, :customer_id

  drop_table :line_items if table_exists? :line_items
  create_table :line_items do |t|
    t.integer :order_id, null: false
    t.integer :item_id
    t.string :item_type
    t.integer :category_id, null: false
    t.decimal :amount, precision: 10, scale: 2
  end
  add_index :line_items, :item_id

  drop_table :users if table_exists? :users
  create_table :users do |t|
    t.integer :customer_id
    t.string :username
    t.timestamps null: false
  end
  add_index :users, :customer_id

  drop_table :offices if table_exists? :offices
  create_table :offices do |t|
    t.string :name
    t.boolean :active
  end

  drop_table :offices_users if table_exists? :offices_users
  create_table :offices_users, id: false do |t|
    t.integer :user_id, null: false
    t.integer :office_id, null: false
  end

  drop_table :health_conditions if table_exists? :health_conditions
  create_table :health_conditions, primary_key: "int_id" do |t|
    t.string :name
    t.integer :icd10_id, null: false
  end

  drop_table :icd10s if table_exists? :icd10s
  create_table :icd10s do |t|
    t.string :code, null: false
    t.string :name, null: false
  end
end

class CategoryType < ActiveRecord::Base
  has_many :categories, primary_key: "code", foreign_key: "type_code"
end

class Category < ActiveRecord::Base
  belongs_to :category_type, foreign_key: "type_code", primary_key: "code"
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
  has_one :category, through: :widget
end

class Spline < ActiveRecord::Base
  belongs_to :category
  has_many :line_items, as: :item
end

class Customer < ActiveRecord::Base
  has_many :orders
  has_one :latest_order, -> { order "date DESC" }, class_name: "Order"
  has_many :line_items, through: :orders
  has_many :items, through: :line_items
  has_many :categories, through: :line_items
end

class Order < ActiveRecord::Base
  belongs_to :customer
  has_many :line_items
  has_many :ordered_line_items, -> { order("item_type") }, class_name: "LineItem"
end

class LineItem < ActiveRecord::Base
  belongs_to :order
  belongs_to :item, polymorphic: true
  belongs_to :category
end

class User < ActiveRecord::Base
  belongs_to :customer
  has_and_belongs_to_many :offices
end

class Office < ActiveRecord::Base
  has_and_belongs_to_many :users
  has_many :customers, through: :users
end

class HealthCondition < ActiveRecord::Base
  self.primary_key = "int_id"
  belongs_to :icd10
end

class Icd10 < ActiveRecord::Base
  has_many :health_conditions
end
