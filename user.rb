class User < ApplicationRecord
	acts_as_reader

	ALLOWED_ROLES = ['tasker', 'customer']
	TEMP_EMAIL_PREFIX = 'change@me'
    TEMP_EMAIL_REGEX = /\Achange@me/
	attr_accessor :eula
	attr_accessor :accept_privacy
	# Include default devise modules. Others available are:
	# :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
	devise :database_authenticatable, :registerable,
		:recoverable, :rememberable, :validatable,
		:confirmable, :lockable, :timeoutable, :trackable, :omniauthable, omniauth_providers: [:google_oauth2, :facebook]

	#
	# callbacks
	#

	after_commit :assign_customer_id, on: :create
	after_create :send_admin_email_on_register
	#for user online or not
	after_update_commit :update_user_status


	#
	# validations
	#validates_presence_of :first_name, :last_name,:phone_number,:email
	#
	validate :individual_first_name
	validates :email, presence: true, email_format: { message: "address not seems to be valid address"}				 
	validates :phone_number,:presence => true,:numericality => true, :length => { :minimum => 9, :maximum => 12 }
				 
	# validate :individual_last_name
	#
	# Associations
	#
	has_many :offers, dependent: :destroy
	has_many :job_posts, dependent: :destroy
	has_one :identity, dependent: :destroy
	has_one :insurance, dependent: :destroy
	has_many :identities, dependent: :destroy
	has_one  :profile_image, :as => :assetable, :class_name => "User::ProfileImage",  :dependent => :destroy
	has_one  :license_image, :as => :assetable, :class_name => "User::LicenseImage",  :dependent => :destroy
	has_many :upload_images, :as => :assetable, :class_name => "User::UploadImage", :dependent => :destroy
	has_many :previous_work_images, :as => :assetable, :class_name => "User::PreviousWorkImage", :dependent => :destroy
	has_one  :address, :as => :addressable, :class_name => "User::Address",  :dependent => :destroy
	has_one :owned_users_company,-> {where(is_owner: true)}, class_name: "CompanyUser", :dependent => :destroy
	has_one :owned_company, through: :owned_users_company, class_name: "Company", source: :company
	
	has_many :users_companies, class_name: "CompanyUser", :dependent => :destroy
	has_many :companies, through: :users_companies
	
	has_one  :profile, :dependent => :destroy
	has_one  :license, :as => :licensable, :class_name => "User::License",  :dependent => :destroy
	has_one  :payment_information, :as => :payable, :class_name => "User::PaymentInformation",  :dependent => :destroy
    belongs_to :work_information, optional: true
	has_many :subscriptions, dependent: :destroy
	has_many :user_tasks, dependent: :destroy
	has_many :packages, dependent: :destroy
	has_many :offer_laters, dependent: :destroy
	has_many :reports, :as => :reportable,   :class_name => "User::Report", :dependent => :destroy
	has_many :sold_user_packages, foreign_key: :seller, class_name: "UserPackage", dependent: :destroy
	has_many :sold_packages, -> { distinct }, through: :sold_user_packages, class_name: "Package", source: :package
	has_many :bought_user_packages, foreign_key: :buyer,class_name: "UserPackage", dependent: :destroy
	has_many :bought_packages, -> { distinct }, through: :bought_user_packages, class_name: "Package", source: :package
	has_one :active_subscription, -> { where(status: Subscription.statuses[:active])}, :dependent => :destroy
	has_many :my_chatrooms, as: :roomable, :class_name => "User::Chatroom", dependent: :destroy
	has_many :reviews, :dependent => :destroy
	has_many  :carts,  :dependent => :destroy
	has_many :notifications, dependent: :destroy
	accepts_nested_attributes_for :companies,:previous_work_images,
		:address, :work_information	, :insurance, :license , :payment_information, :profile, :profile_image
	#
	# scopes
	#
	scope :taskers, -> { where(role: 'tasker') }
	scope :customers, -> { where(role: 'customer') }

	#
	# methods
	#

	def reviews_for_tasker
		Review.includes(:user).where("reviewable_type IN (?) AND reviewable_id IN (?) AND user_id != ?",["JobPost", "UserPackage", "Offer"], (JobPost.where("user_id != ? AND id IN (?)", self.id, Offer.where(user_id: self.id).pluck(:job_post_id))).pluck(:id) + sold_user_packages.pluck(:id), self.id).where.not(user_id: sold_user_packages.pluck(:seller_id))
	end

	def reviews_for_poster
		Review.includes(:user).where("reviewable_type IN (?) AND reviewable_id IN (?) AND user_id != ?",["JobPost", "UserPackage", "Offer"], JobPost.where(user_id: self.id).pluck(:id) + bought_user_packages.pluck(:id), self.id).where.not(user_id: bought_user_packages.pluck(:buyer_id))
	end

	def self.find_for_oauth(auth, signed_in_resource = nil)
		identity = Identity.find_for_oauth(auth)
		user = signed_in_resource ? signed_in_resource : identity.user
		if user.nil?
			email = auth.info.email rescue nil
			user = User.where(:email => email).first if email
			if user.nil?
				if auth.provider == "facebook"
					user = User.new(
						first_name: auth.extra.raw_info.name,
						last_name: auth.extra.raw_info.lastName,
						email: email ? email : "#{User::TEMP_EMAIL_PREFIX}-#{auth.uid}-#{auth.provider}.com",
						password: Devise.friendly_token[0,12]
					)
				elsif auth.provider == "google_oauth2"
					user = User.new(
						first_name: auth.info.first_name,
						last_name: auth.info.last_name,
						email: email ? email : "#{User::TEMP_EMAIL_PREFIX}-#{auth.uid}-#{auth.provider}.com",
						password: Devise.friendly_token[0,12]
					)
				else
					raise "Not a valid provider"
				end
			end
		end
		if identity.user != user
			identity.user = user
			user.save(validate: false)
			identity.save!
		end
		user
	end

	def get_active_cart!
		cart = self.carts.find_by(active: true)
		unless cart
			cart = self.carts.new
			cart.save
		end
		cart
	end
	
	def cart_items
		cart = self.carts.find_by(active: true)
		return cart.cart_items
	end

	def cart_items_count
		cart = self.carts.find_by(active: true)
		unless cart
			cart = self.carts.new
			cart.save
		end
		return cart.cart_items.count
	end

	def any_company?
		companies.any?
	end

	def my_company
		companies.last
	end
	
	def full_name
		if self.companies.any?
			[self.companies.last.owner_first_name, self.companies.last.owner_last_name].select(&:present?).join(' ').titleize
		else
			[first_name, last_name].select(&:present?).join(' ').titleize
		end
	end

	# check to see if a user is active or not and deny login if not
	def active_for_authentication?
		super && (self.is_active)
	end
 
	# flash message for the inactive users
	def inactive_message
		"Sorry, this account not active by admin. Will Contact you soon."
	end

	def update_step4_params
		if self.active_subscription.present?
			@plan = self.active_subscription.plan
			self.update_attributes!(leads_count: @plan.number_of_leads, quotations_count: @plan.number_of_quotations, profile_completed: true)
		end
	end

	def profile_image_url
		build_profile_image unless profile_image
		profile_image.url
	end

	def subscribe_free_plan! _plan
		_subscription = self.subscriptions.new(plan_id: _plan.id)
    	_subscription.save
	end
	 
	def load_single_chatrooms( search = nil )
		sql = "
			SELECT 
				DISTINCT(chatrooms.id)
			FROM 
				chatrooms 
			INNER JOIN
				chatroom_users
			ON 
				chatroom_users.chatroom_id = chatrooms.id
			WHERE (
				(chatrooms.user_id = '#{self.id}' AND chatrooms.opponent_id != '#{self.id}')
			OR 
				(chatrooms.opponent_id = '#{self.id}' AND chatrooms.user_id != '#{self.id}')
			) AND
				chatrooms.chat_type_cd = 0
			AND
				chatrooms.roomable_type = 'User'"
		if search.present?
			sql += "
			AND 
				chatrooms.user_id IN (
					SELECT
						users.id
					FROM
						users
					WHERE (
							(lower(first_name) iLIKE '%#{search.downcase}%'
						OR
							lower(last_name) iLIKE '%#{search.downcase}%')
						AND
							chatroom_users.user_id = '#{self.id}'
					)
				)"
		end
		query = Chatroom.connection.execute(sql)

		Chatroom.where(id: query.values.flatten)
	end

	def save_work_information(data = "")
		_work = self.work_information
		if data.present?
			_vehicle = data.join(",")
		else
			_vehicle = ""
		end
		_work.update_column(:vehicle, _vehicle)
	end

	def show_user_vehicles
		self.work_information.vehicle.to_s
	end

	def get_open_count
		self.job_posts.where(job_status: "open")
	end

	def get_assigned_count
		self.job_posts.where(job_status: "assigned")
	end

	def get_complete_count
		self.job_posts.where(job_status: "complete")
	end

	def get_cancelled_count
		self.job_posts.where(job_status: "cancelled")
	end

	def open_offer
		offers.where(status_cd: Offer.statuses[:pending])
	end
	def assigned_offer
		offers.where(status_cd: Offer.statuses[:accepted])
	end
	def complete_offer
		offers.where(status_cd: Offer.statuses[:completed])
	end
	def cancelled_offer
		offers.where(status_cd: Offer.statuses[:rejected])
	end
	def momentize
		self.try(:created_at).try(:iso8601)
	end
	
	def profile_complete
		self.profile.present? && self.profile_image.present? && self.phone_number.present? && self.address.complete_address.present?
	end


	def general_message_count
		# slow need to refactor might be we will take fields to relect these value
		load_single_chatrooms.collect { |chatroom| chatroom.messages.unread_by(self).count unless chatroom.is_hidden_for(self) }.compact.sum
	end

	def task_related_message_count
		# slow need to refactor might be we will take fields to relect these value
		Chatroom.group_chatrooms_data(self, nil).uniq(&:roomable_id).collect { |chatroom| chatroom.unread_count_for(self) unless chatroom.is_hidden_for(self) }.compact.sum
	end

	protected
	
	def confirmation_required?
		false
	end
	

	private

	def assign_customer_id
		customer = Stripe::Customer.create(email: email)
		self.customer_id = customer.id
	end

	def individual_first_name
	   return if self.companies.present?
		if self.first_name.blank?
	    	errors.add(:first_name, "is required")
		end	
	end

	def individual_last_name
		return if self.companies.present?
		if self.last_name.blank?
	    	errors.add(:last_name, "is required")
		end	
	end

	def send_admin_email_on_register
		if self.email.present?
		  UserMailer.send_admin_user_notify_on_register(self.id).deliver_later(wait: 15.seconds)
		  UserMailer.welcome_email(self.id).deliver_later(wait: 15.seconds)
		end
	end

	#update online/offline
	def update_user_status
		AppearanceBroadcastJob.perform_later self.id
	end


end