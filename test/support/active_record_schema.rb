ActiveRecord::Base.logger = nil

module Schema
  def self.load!
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

      drop_table :commons if table_exists? :commons
      create_table :commons do |t|
        t.string :name
        t.text :desc
        t.integer :int
        t.float :flt
        t.decimal :dec, precision: 10, scale: 3
        t.date :day
        t.datetime :daytime
        t.boolean :bool
        t.integer :status
      end

      drop_table :exotics if table_exists? :exotics
      if ActiveRecord::Base.connection.class.name =~ /postgres/i
        enable_extension "hstore"
        enable_extension "pgcrypto"
        enable_extension "uuid-ossp"

        create_table :exotics, id: :uuid do |t|
          t.json :data1
          t.jsonb :data2
          t.hstore :data3
          t.string :tags, array: true
        end
      end
    end
  end
end
