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

  def detail_with_category(arg = nil, &block)
    vals = [category.name, detail.text]
    vals << arg if arg
    vals << block.call if block
    vals.join(" - ")
  end
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

class Common < ActiveRecord::Base
  if ActiveRecord::VERSION::MAJOR >= 7
    enum :status, [:pending, :active, :disabled]
  else
    enum status: [:pending, :active, :disabled]
  end
end

class Exotic < ActiveRecord::Base
end
