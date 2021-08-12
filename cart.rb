class Cart < ApplicationRecord
	
	#
	# associations
	#
	
	belongs_to :user
	has_many :cart_items, dependent: :destroy


	def add_item!(obj)
		_result = nil
		if obj.class.name == "JobPost"
			_result = obj.cart_items.find_or_create_by(cart_id: self.id, price_cents: obj.budget_amount_cents)
		elsif obj.class.name == "Package"
			_result = obj.cart_items.find_or_create_by(cart_id: self.id, price_cents: obj.sale_price)
		end
		_result
	end
end
class CartItem < ApplicationRecord
	monetize :price_cents
	#
	# associations
	#
	
	belongs_to :cart
	belongs_to :itemable, :polymorphic => true

	#
	#callbacks
	#
	after_create :send_cart_notification,on: :create

 	def momentize
		self.try(:created_at).try(:iso8601)
	end


	private

	def send_cart_notification
		Notification.create(notify_type: 'CartItem', target: self, actor: self.cart.user, user: self.itemable.user, message: "added  your job post to cart")
	end
end