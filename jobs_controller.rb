class JobsController < ApplicationController
	before_action :authenticate_user!, only: [:public_profile, :remove_assignee,:mark_complete, :report, :submit_report, :post_comment, :reply_comment, :make_offer, :cancel_post, :existing_tasks]
    # before_action :authenticate_user!, except: [:create]
    layout "tasker"
    before_action :find_job, only: [:add_review,:submit_review, :remove_assignee, :mark_complete, :show, :edit, :update, :destroy, :report, :submit_report, :post_comment, :reply_comment, :make_offer, :offer_later, :make_money, :submit_offer_later, :make_job_offer, :cancel_post]
    before_action :get_selected_images, only: [:new, :create, :edit, :update]
    require 'will_paginate/array'
    
	def index
		@user = current_user
		@task_categories = JobPost.job_post_tasks.order(created_at: :desc)
		@job_posts = JobPost.open_jobs.order(updated_at: :desc)
		if params[:search].present?
			@job_posts = JobPost.where(admin_approval: false).search(params[:search]).order(updated_at: :desc)
		end

		if params[:cat_id].present?
			@job_posts = @job_posts.where(task_category_id: params[:cat_id]).order(updated_at: :desc)
		end

		if params[:category_id].present? && params[:task_id]
			@job_posts = @job_posts.where(task_category_id: params[:category_id], task_id: params[:task_id]).order(updated_at: :desc)
		end

		if params[:task_type] == "on"
			@job_posts = @job_posts.task_type.order(updated_at: :desc)
		end
		
		if params[:work_location_type].present?
			if params[:work_location_type] == "In Person" && params[:distance].present?
				@distance = params[:distance].to_i
				@address = [params[:lat].to_f, params[:lng].to_f]
				@job_posts = @job_posts.joins(:address).within(@distance, :origin => @address).order(updated_at: :desc)
			
			elsif params[:work_location_type] == "Remotely"
				@job_posts = @job_posts.remotely.order(updated_at: :desc)
			end
		end

		if params[:price_range].present?
			@job_posts = @job_posts.where(budget_amount_cents: params["lowest_price"].to_i..params["highest_price"].to_i).order(created_at: :desc)
		end

		@job_posts = @job_posts.paginate(page: (params[:page] || 1), per_page: 6)

		@job_post = nil

		@page_present = params[:page].present?

		respond_to do |format|
			format.html
			format.js
		end
	end

	def new
		@address = params[:name]
		@searched_word = params["title"]
		@name = params[:name]
		@lat = params[:lat]
		@lng =  params[:lng]
		@city = params[:city]
		@country_name = params[:country_name]

		unless params["title"].present?
			(redirect_to "/" and return) unless params[:job_id].present?
		end
		@type = 'describe'
		if params[:job_id].present?
			_job_post = JobPost.find(params[:job_id])
			@job_post = _job_post.clone_deep #current_user.job_posts.new(_job_post.attributes.except("id", "created_at", "updated_at", "job_status", "is_active", "admin_approval"))
			@questions = Question.where(id: @job_post.job_post_questions.map(&:question_id))
		else
			if session[:job_data].present?
				@is_active = session[:job_data]["is_active"]
				(params || {}).merge!(session[:job_data].with_indifferent_access)
				_save_obj = false
				params = session[:job_data] if session[:job_data].present?
				@type = params[:type] || 'describe'
				@job_post = current_user.job_posts.new(job_params)
				if @job_post.task_category_id && @job_post.task_id.present?
					@job_post.task_id = nil unless @job_post.task_category.tasks.where(id: @job_post.task_id).exists?
				end

				@questions = []
				if @job_post.task_id.present?
					if @job_post.job_post_questions.any?
						@questions = Question.where(id: @job_post.job_post_questions.map(&:question_id))
					else
						@questions = Question.where(questionable_type: "Task", questionable_id: @job_post.task_id).order("RANDOM()").limit(2)
					end
				end
				session[:job_data] = nil
				if @job_post.valid?
					if @is_active.present?
						@job_post.is_active = true
					else
						@job_post.admin_approval = true	
					end
					_save_obj = (params["commit"] == "Get Quote From Our Taskhub Partners") || params["is_active"] == "Get Quote From Taskers" || params["is_active"] == "Repost"
					job_post_images
					if _save_obj
						if @job_post.save
							cookies.delete :selectedImageID
						end
					end
					redirect_to(job_path(@job_post, afterSignin: true), notice: 'Job Created') and return
				else
					render 'new'
				end
			else
				@job_post = JobPost.new(searched_word: @searched_word)
				@job_post.build_address(name: @name, lat: @lat, lng: @lng, city: @city, country_name: @country_name)
				@questions = []
				if TaskCategory.find_by(id: @searched_word).present?
					_task_category = TaskCategory.find_by(id: @searched_word)
					@job_post.searched_word = _task_category.name
					@job_post.task_category = _task_category
				elsif Task.find_by(id: @searched_word).present?
					_task = Task.find_by(id: @searched_word)
					@job_post.task_category = _task.task_category
					@job_post.task = _task
					@job_post.searched_word = _task.name
					@questions = _task.questions.order('RANDOM()').first(2)
				end
			end
		end
	end

	def create
		@error = nil
		@type = params[:type]
		@is_active = params[:is_active]
		@commit = params["commit"]
		@category_id = params[:category_id]
		@session_params = params

		begin
			_save_obj = false
			params = session[:job_data] if session[:job_data].present?
			@type = @type || 'describe'
			if current_user
				@job_post = current_user.job_posts.new(job_params)
			else
				@job_post = JobPost.new(job_params)
			end
			if @job_post.task_category_id && @job_post.task_id.present?
				@job_post.task_id = nil unless @job_post.task_category.tasks.where(id: @job_post.task_id).exists?
			end

			@questions = []
			if @job_post.task_id.present?
				if @job_post.job_post_questions.any?
					@questions = Question.where(id: @job_post.job_post_questions.map(&:question_id))
				else
					@questions = Question.where(questionable_type: "Task", questionable_id: @job_post.task_id).order("RANDOM()").limit(2)
				end
			end
			respond_to do |format|
				if @job_post.valid?
					if @is_active.present?
						@job_post.is_active = true
					else
						@job_post.admin_approval = true	
					end
					_save_obj = (@commit == "Get Quote From Our Taskhub Partners") || @is_active == "Get Quote From Taskers" || @is_active == "Repost"
					job_post_images
					if _save_obj
						if @job_post.save
							cookies.delete :selectedImageID
						end
					end
					@packages = Package.demand_task_packages.joins(:package_tasks).where(package_tasks: {task_category_id: @category_id}).group('packages.id').uniq
					format.html { redirect_to(root_path, notice: 'Job Created') }
					format.js
				else
					if current_user.nil? && (@commit.present? || @is_active.present?)
						# Store the form data in the session so we can retrieve it after login
						session[:job_data] = @session_params
						# Redirect the user to register/login
						redirect_to "/login?source=header"  and return 
					else
						format.html { render 'new' }
						format.js
					end
				end
			end
		rescue Exception => e
			@error = e.message
			puts "\n\n\n #{e.message} \n\n\n"
		end
	end

	def edit
		(redirect_to "/", alert: "Invalid access" and return) unless @job_post.user == current_user
		@type = params[:type] || 'describe'
		@questions = []
		if @job_post.task_id.present?
			if @job_post.job_post_questions.any?
				@questions = Question.where(id: @job_post.job_post_questions.map(&:question_id))
			end
		end
		respond_to do |format|
			format.html
			format.js
		end
	end

	def update
		@type = params[:type] || 'describe'
		@questions = []
		if @job_post.task_id.present?
			if @job_post.job_post_questions.any?
				@questions = Question.where(id: @job_post.job_post_questions.map(&:question_id))
			end
		end
		respond_to do |format|
			@updated = false
			@job_post.attributes = job_params
			if @job_post.valid?
				if params[:is_active].present?
					@job_post.is_active = true
					@updated = true
				end
				job_post_images
				@job_post.update(job_params) if @updated

				format.html { redirect_to(root_path, notice: 'Job Created') }
				format.js
			else
				format.html { render 'new' }
				format.js
			end
		end
	end

	def show
		@task_categories = JobPost.job_post_tasks.order(created_at: :desc).uniq
		@job_posts = JobPost.open_jobs.order(updated_at: :desc).paginate(page: (params[:page] || 1), per_page: 6)
		@user = current_user
		@comments = @job_post.comments.order(updated_at: :desc).paginate(page: (params[:page] || 1), per_page: 6)
		@page_present = params[:page].present?
	end

	def destroy
		_job_post = JobPost.find(params[:id])
		respond_to do |format|
			if  _job_post.destroy
				format.html { redirect_back(fallback_location: root_path, notice: "Job post deleted")}
			else
				format.html { render :new, notice: 'Job post is not deleted'}
			end
		end
	end

	def report
		@user = current_user
		@report = @job_post.reports.new(user: current_user)
	end

	def submit_report
		@user = current_user
		@report = @job_post.reports.new(report_params)
		respond_to do |format|
			if @report.valid?
				if @report.save
					ReportMailer.report_job_post_email(@report).deliver_later(wait: 15.seconds)
				end
				format.html { redirect_to(root_path, notice: 'Report sent! ') }
				format.js
			else
				format.html { render 'new' }
				format.js
			end
		end
	end

	def post_comment
		@user = current_user
		@comment = @job_post.comments.new(comment_params)
		@comment.user_id = current_user.id
		respond_to do |format|
			if @comment.valid?
				if @comment.save
					format.html { redirect_back(fallback_location: root_path, notice: "Saved")}
					format.js
				else
					format.html { redirect_back(fallback_location: root_path, error: "not Saved")}
					format.js
				end
			else
				format.html { redirect_back(fallback_location: root_path, error: "not Saved")}
				format.js
			end
		end
	end

	def add_comment
		@user = current_user
		@job_post = JobPost.find(params[:id])
	end

	def reply_comment
		@user = current_user
	end

	def make_offer

	end

	def make_money
		@user = current_user
	end

	def make_job_offer
		@user = current_user
		@offer = Offer.new
		respond_to do |format|
			if @user.valid?
				@user.update(make_offer_params)
				format.html { redirect_to(root_path, notice: 'Offer Submitted ') }
				format.js
			else
				format.html { render 'new' }
				format.js
			end
		end
	end

	def offer_later
		@user = current_user
		@offer_later = @job_post.offer_laters.new(user_id: @user.id)
	end

	def submit_offer_later
		@user = current_user
		@offer_later = @job_post.offer_laters.new(offer_params)
		@offer_later.user_id = @user.id
		offer_later_images
		respond_to do |format|
			if @offer_later.valid?
				if @offer_later.save
					format.html { redirect_back(fallback_location: root_path, notice: "Saved")}
					format.js
				else
					format.html { redirect_back(fallback_location: root_path, error: "not Saved")}
					format.js
				end	
			else
				format.html { redirect_back(fallback_location: root_path, error: "not Saved")}
				format.js
			end
		end
	end
	
	def public_profile
		if params[:job_id].present?
			@job_post = JobPost.find(params[:job_id])
		end
		@user = User.find_by(id: params[:user_id])
		@tab = params[:tab] || 'tab0'
		if @tab == 'tab1'
			@bought_user_packages = @user.bought_user_packages
			@avg_reviews = @user.reviews_for_poster
			@reviews = @user.reviews_for_poster.order(updated_at: :desc).paginate(page: (params[:page] || 1), per_page: 3)
		else
			@sold_user_packages  = @user.sold_user_packages
			@avg_reviews = @user.reviews_for_tasker
			@reviews = @user.reviews_for_tasker.order(updated_at: :desc).paginate(page: (params[:page] || 1), per_page: 3)
		end
		unless params[:tab].present?
			@task_category = TaskCategory.where(user_id: @user.id)
			@work_gallery = @user.previous_work_images.last(6)
		end
	end 

	def request_quote
		@user = User.find(params[:id])
	end

	def get_job_post_images
		@job_post = JobPost.find(params[:id])
		@images = @job_post.images
		render 'jobs/get_job_post_images'
	end

	def get_images
		_ids = params['ids'].split(",") rescue ""
		@images = Asset.where(id: _ids)
		render 'jobs/get_job_post_images'
	end

	def existing_tasks
		@user = User.find_by(id: params[:id])
		@job_posts = current_user.get_open_count.paginate(page: (params[:page] || 1), per_page: 6)
		render :layout => 'dashboard'
	end

	def cancel_post
		if params[:job_status] == "cancelled"
			@job_post.update(job_status: JobPost.job_statuses[:cancelled])
			@job_post.offers.destroy_all
			redirect_to bookings_path , notice: 'Job cancelled.'
		else
			redirect_to bookings_path(inner_tab: "tab0",tab: "tab0") , alert: 'Job not cancelled.'
		end 
	end

	def mark_complete
		if @job_post.update(job_status: JobPost.job_statuses[:complete]) &&
			@job_post.get_accepted_offer.update(status_cd: Offer.statuses[:completed])
			redirect_back(fallback_location: root_path, notice: "Success")
		end	
	end

	def remove_assignee
		if @job_post.update(job_status: JobPost.job_statuses[:open]) && 
			@job_post.open_offer.update(status_cd: Offer.statuses[:pending])
			@review = @job_post.reviews.new(user: current_user)
		end
	end

	def add_review
		@user = current_user
		@review = @job_post.reviews.new(user: current_user)
	end

	def submit_review
		@user = current_user
		@review = @job_post.reviews.new(review_params)
		respond_to do |format|
			if @review.valid?
				@review.save
				format.html { redirect_to(root_path, notice: 'Report sent! ') }
				format.js
			else
				format.html { render 'new' }
				format.js
			end
		end
	end

	private

	def job_params
		params.require(:job_post).permit(:job_status, :searched_word, :task_category_id, :task_id, :budget_type_cd,:budget_amount_cents, :budget_amount_currency, :work_location_type_cd, :work_expected_type_cd,:work_expected_date, :title, :description,	:rate_per_hour_cents, :number_of_hours, :search,
			images_attributes: [:id, :attachment],
			address_attributes: [:id, :name, :lat, :lng, :city, :country_name],
			job_post_questions_attributes: [:id, :question_id, :answer_id, :answer_text]
		)
	end

	def find_job
		@job_post = JobPost.find(params[:id])
	end

	def report_params
		params.require(:job_post_report).permit(:user_id, :title, :reason)
	end

	def comment_params
		params.require(:job_post_comment).permit(:body)
	end

	def offer_params
		params.require(:offer_later).permit(:total_amount_cents, :per_hour_rate_cents, :user_id, :job_post_id, :amount_type, :available_type, :available_date, :description)
	end

	def make_offer_params
		params.require(:user).permit(:phone_number, profile_image_attributes: [:id, :attachment], profile_attributes: [:id, :dob], address_attributes: [:id, :name, :city, :postal_code, :country_name, :state_name,:lat, :lng])
	end

	def offer_later_images
		if params["offer_later"] && params["offer_later"]["attached_ids"]
			@offer_later.add_attachments(params["offer_later"]["attached_ids"])
		end
    end

    def job_post_images
    	if params["job_post"] && params["job_post"]["attached_ids"]
			@job_post.add_attachments(params["job_post"]["attached_ids"])
		end
    end

    def profile_image
		if params["user"] && params["user"]["attached_ids"]
			@user.add_attachments(profile_image: params["user"]["attached_ids"])
		end
	end

	def get_selected_images
		@image_ids = helpers.get_selected_images
	end

	def review_params
		params.require(:job_post_review).permit(:user_id, :message, :rating_number)
	end
end