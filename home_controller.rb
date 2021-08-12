class HomeController < ApplicationController

	before_action :authenticate_user!, only: [:quotes, :complete_profile, :update_profile]
	skip_before_action :redirect_chain, only: [:update_profile]
	require 'will_paginate/array'
	respond_to :html, :json

	def index
		@task_categories = TaskCategory.task_list
		@type = params[:category_id] || 'all'
		if @type == 'all'
			@packages = Package.home_packages.uniq.paginate(page: (params[:page] || 1), per_page: 12)
		else
			@packages = Package.home_packages.joins(:package_tasks).where(package_tasks: {task_category_id: params[:category_id]}).group('packages.id').uniq.paginate(page: (params[:page] || 1), per_page: 10)
		end

		@job_categories = TaskCategory.open_job_category.job_task_list
		if @type == 'all'
			@job_posts = JobPost.includes(:task_category).open_jobs.order(created_at: :desc).paginate(page: (params[:page] || 1), per_page: 12)
		else
			@job_posts = JobPost.includes(:task_category).open_jobs.where(task_category_id: params[:category_id]).order(created_at: :desc).paginate(page: (params[:page] || 1), per_page: 12)
		end
		if params[:showMenu].present?
			@task_category = TaskCategory.find(params[:id])
			@task = Task.menu_category.where(task_category_id: @task_category.id).first(7)
		end
	end

	def load_packages_data
		@package_categories = TaskCategory.task_list
		@type = params[:category_id] || 'all'
		
		if @type == 'all'
			@packages = Package.home_packages.uniq.paginate(page: (params[:page] || 1), per_page: 12)
		else
			@packages = Package.home_packages.joins(:package_tasks).where(package_tasks: {task_category_id: params[:category_id]}).group('packages.id').uniq.paginate(page: (params[:page] || 1), per_page: 10)
		end
	end

	def load_job_data
		@job_categories = TaskCategory.job_task_list
		@type = params[:category_id] || 'all'
		
		if @type == 'all'
			@job_posts = JobPost.includes(:task_category).open_jobs.paginate(page: (params[:page] || 1), per_page: 12)
		else
			@job_posts = JobPost.includes(:task_category).open_jobs.where(task_category_id: params[:category_id]).paginate(page: (params[:page] || 1), per_page: 12)
		end
	end

	def pages
		@page = Page.get(params[:id]) || Page.new
	end

	def complete_profile
		@user = current_user
		@type = params["type"] || "individual"
		render layout: "register_complete"
	end

	def update_profile
		@user = current_user
		@type = params["type"] || "individual"
		respond_to do |format|
			if current_user.update(update_params)
				bypass_sign_in current_user
				format.html { redirect_to "/" , notice: 'Success!' }
			else
				format.html { render "complete_profile", layout: "register_complete", alert: 'Failed' }
			end
		end
	end

	def load_tasks
		@tasks = Task.where('name ILIKE :q', q: "%#{params[:q]}%")
        respond_with @tasks
	end

	def load_task_categories
		@task_categories = TaskCategory.where('task_categories.name ILIKE ?', "%#{params[:q]}%")
	end

	def load_all_cat
		tasks = Task.where('name ILIKE :q', q: "%#{params[:q]}%")
		task_categories = TaskCategory.where('task_categories.name ILIKE ?', "%#{params[:q]}%")
		@records = [tasks + task_categories].flatten

		@records = WillPaginate::Collection.create(params[:page] || 1, 20, @records.size) do |pager|
		  pager.replace(@records)
		end
	end


	private

	def update_params
		params.require(:user).permit(
			:first_name, :last_name, :email, :password, :phone_number, :role, 
			address_attributes: [:id, :name, :city, :postal_code, :country_name, :lat, :lng],
			companies_attributes: [:id, :name]
		)
	end
end