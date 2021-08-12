class PaymentMethodsController < ApplicationController
	before_action :authenticate_user!
	before_action :find_payment_method, only: [:show, :destroy]

	before_action :check_required_element, only: [:create, :new]

	def index
		@payment_method = current_user.payment_method
	end
	
	def new
		@payment_method = current_user.build_payment_method
	end

	def create
		begin
			@payment_method = current_user.build_payment_method(payment_method_params)
			respond_to do |format|
				if @payment_method.save
					format.html { redirect_to payment_methods_path, notice: 'Payment Method successfully Added.' }
				else
					format.html { redirect_to payment_methods_path, alert: @payment_method.errors.messages }
				end
			end
		rescue Exception => e
			redirect_to payment_methods_path, alert: 'Something went Wrong.'
		end
	end

	def destroy
		@payment_method.destroy
		respond_to do |format|
			format.html { redirect_to payment_methods_path, notice: 'Payment Method was successfully destroyed.' }
			format.json { head :no_content }
		end
	end

	private

	# Use callbacks to share common setup or constraints between actions.
	def find_payment_method
		@payment_method = PaymentMethod.find(params[:id])
	end

	def check_required_element
		#Check if already created
		if current_user.payment_method.present?
			redirect_to("/", alert: "Payment Method already added!") and return
		end

		#check for user address
		unless current_user.address
			redirect_to("/", alert: "User Address is not saved in profile!") and return
		end

		# check for user payment id
		unless current_user.payment_customer_id
			redirect_to("/", alert: "User has no payment id!") and return
		end
	end

	def payment_method_params
		params.require(:payment_method).permit(:acc_number, :routing_number)
	end
end