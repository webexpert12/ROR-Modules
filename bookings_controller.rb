class BookingsController < ApplicationController
	before_action :authenticate_user!
	layout "dashboard"
	
	def index
		@tab = (params[:tab] || 'tab0')
		@inner_tab = (params[:inner_tab] || 'tab0')
		if @tab == "tab0"
			if @inner_tab == "tab0"
				@job_posts = current_user.get_open_count.order(updated_at: :desc).paginate(page: (params[:page] || 1), per_page: 6)
			elsif @inner_tab == "tab1"
				@job_posts = current_user.get_assigned_count.order(updated_at: :desc).paginate(page: (params[:page] || 1), per_page: 6)
			elsif @inner_tab == "tab2"
				@job_posts = current_user.get_complete_count.order(updated_at: :desc).paginate(page: (params[:page] || 1), per_page: 6)
			else
				@job_posts = current_user.get_cancelled_count.order(updated_at: :desc).paginate(page: (params[:page] || 1), per_page: 6)
			end
		else
			if @inner_tab == "tab0"
				@offers = current_user.open_offer.order(updated_at: :desc).paginate(page: (params[:page] || 1), per_page: 6)
			elsif @inner_tab == "tab1"
				@offers = current_user.assigned_offer.order(updated_at: :desc).paginate(page: (params[:page] || 1), per_page: 6)
			elsif @inner_tab == "tab2"
				@offers = current_user.complete_offer.order(updated_at: :desc).paginate(page: (params[:page] || 1), per_page: 6)
			else
				@offers = current_user.cancelled_offer.order(updated_at: :desc).paginate(page: (params[:page] || 1), per_page: 6)
			end
		end
				
	end

	def review_offer
		@user = current_user
		@tab = (params[:tab] || 'tab0')
		@job_post = JobPost.find_by(id: params[:booking_id])
		@sort = params[:sort] || 'newest'
		if @tab == "tab0" 
		elsif @tab == "tab1"
			if @sort == "oldest"
				@offers = @job_post.offers.where(status_cd: Offer.statuses[:pending]).order(updated_at: :asc).paginate(page: (params[:page] || 1), per_page: 6)
			elsif @sort == "highest"
				@offers = @job_post.offers.where(status_cd: Offer.statuses[:pending]).order(total_amount_cents: :desc).paginate(page: (params[:page] || 1), per_page: 6)
			elsif @sort == "lowest"
				@offers = @job_post.offers.where(status_cd: Offer.statuses[:pending]).order(total_amount_cents: :asc).paginate(page: (params[:page] || 1), per_page: 6)
			else
				@offers = @job_post.offers.where(status_cd: [Offer.statuses[:pending], Offer.statuses[:completed]]).order(updated_at: :desc).paginate(page: (params[:page] || 1), per_page: 6)
			end
		else @tab == "tab2"
			@offers = @job_post.offers.where(status_cd: [Offer.statuses[:accepted], Offer.statuses[:completed]]).paginate(page: (params[:page] || 1), per_page: 6)
		end
	end

	def view_proposal
		@offer = Offer.find(params[:id])
		@user = @offer.user
		@job = @offer.job_post
	end

	def update_job
		
		_offer = Offer.find(params[:booking_id])

		case params[:status]

		when "rejected"
			_offer.update(status_cd: Offer.statuses[:rejected])
		when "accepted"
			_offer.update(status_cd: Offer.statuses[:accepted])
			_offer.job_post.update(job_status: JobPost.job_statuses[:assigned])
		when "remove_assignee"
			_offer.update(status_cd: Offer.statuses[:pending])
			_offer.job_post.update(job_status: JobPost.job_statuses[:open])
		when "completed"
			_offer.update(status_cd: Offer.statuses[:completed])
			_offer.job_post.update(job_status: JobPost.job_statuses[:complete])
		end

		redirect_back(fallback_location: root_path, notice: "Success")
	end
end