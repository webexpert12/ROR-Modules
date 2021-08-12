module Api::V1
	class BookingsController < ApiController
		skip_before_action :authenticate_request, only: [:number_plate]
		include Swagger::Blocks


		swagger_path '/bookings' do
	      operation :get do
	        key :tags, [
	        'bookings'
	        ]
	        security do
	          key :api_key, []
	        end
	        response 200 do
	          key :description, 'response'
	        end

	      end
	    end

		def index
			paginate current_user.current_jobs, per_page: 10 
		end

		swagger_path '/bookings/notifications' do
	      operation :get do
	        key :tags, [
	        'bookings'
	        ]
	        security do
	          key :api_key, []
	        end
	        response 200 do
	          key :description, 'response'
	        end

	      end
	    end

		def notifications
			paginate current_user.new_available_jobs.order("booking_notifications.created_at desc"), per_page: 10 
		end

		swagger_path '/bookings/accept_reject' do
	      operation :post do
	        key :tags, [
	        'bookings'
	        ]
	        security do
	          key :api_key, []
	        end
	        parameter do
				key :name, :notification_id
				key :in, :formData
				key :description, 'notification_id'
				key :required, true
				key :type, :string
		    end

		    parameter do
	          key :name, 'status'
	          key :in, :formData
	          key :description, "status"
	          key :required, true
	          key :type, :string
	          
	          items do
	             key :type, :string
	             key :enum, [:accept, :reject]
	          end
	        end


	        response 200 do
	          key :description, 'response'
	        end

	      end
	    end

		def accept_reject
			begin
				booking_notification = 
					current_user.booking_notifications.
							where( booking_notifications: {id: params[:notification_id]}).first
				 raise "Booking not found" unless booking_notification
				if params[:status] == 'accept'
					# ACCEPT NOTIFICATION
					begin
						booking_notification.accept!
						render json:  booking_notification, status: 200
					rescue Exception => e
						render json: { message: e.message }, status: 400
					end
				elsif  params[:status] == 'reject'
					# Reject NOTIFICATION
					begin
						booking_notification.reject!
						render json: booking_notification, status: 200
					rescue Exception => e
						render json: { message: e.message }, status: 400
					end
				else
					render json: { message: "param status must present"}, status: 400
				end
					
			rescue Exception => e
				render json: { message: e.message}, status: 400
			end
		end

		swagger_path '/bookings/{id}/mark_finished' do
			operation :post do
				key :tags, [
					'bookings'
				]
				security do
					key :api_key, []
				end
				parameter do
					key :name, 'image_attributes[base64]'
					key :in, :formData
					key :description, "Image base 64 String"
					key :required, true
					key :type, :string
				end

				parameter do
					key :name, 'provider_review_attributes[body]'
					key :in, :formData
					key :description, "body"
					key :required, true
					key :type, :string
				end


				response 200 do
					key :description, 'response'
				end
			end
		end

		def mark_finished
			begin
				@booking = Booking.find(params[:id])
				tr_success = Booking.transaction do |t|
					@booking.update(finish_booking_params) &&
					@booking.mark_finished!
				end
				if tr_success
					render json: { message: "Marked Finished Successfully, You will get payment after admin approval"}, status: 200
				else
					render json: { message: "Cannot mark as Finished"}, status: 400
				end
		    rescue Exception => e
		        render json: { message: e.message}, status: 400
		    end
		end


		swagger_path '/bookings/{id}/cancel' do
			operation :post do
				key :tags, [
					'bookings'
				]

				security do
					key :api_key, []
				end
				parameter do
					key :booking_id, 'image_attributes[base64]'
					key :in, :query
					key :description, "Image base 64 String"
					key :required, true
					key :type, :string
				end

				response 200 do
					key :description, 'response'
				end
			end
		end

		def cancel
			begin
				@booking = Booking.find(params[:id])
				unless @booking.state == 'finished'
					cancelled = @booking.try_cancellation_by_mechanic!
					if cancelled
						render json: { message: "Booking Cencelled successfully"}, status: 200
					else
						render json: { message: "Cannot Cancel booking"}, status: 400
					end
				else
					render json: { message: "Cannot Cancel booking because booking is finished already!"}, status: 400
				end
		    rescue Exception => e
		        render json: { message: e.message}, status: 400
		    end
		end

		swagger_path '/number-plate' do
			operation :post do
				key :tags, [
					'bookings'
				]

				security do
					key :api_key, []
				end

				parameter do
					key :name, :reg_number
					key :in, :formData
					key :description, 'registration number'
					key :required, true
					key :type, :string
				end

				parameter do
					key :name, :user_kms
					key :in, :formData
					key :description, 'User KMs'
					key :required, false
					key :type, :string
				end

				response 200 do
					key :description, 'response'
				end
			end
		end

		def number_plate
			begin
				if params["reg_number"].present?
					ser = VehicleService.new(params["reg_number"])
					response = ser.vehicle_details
					render :json=> JSON.parse(response.parsed_response), :status=> 200
				else
					render json: { message: "Registration number missing!"}, status: 400
				end
			rescue Exception => e
		        render json: { message: e.message}, status: 400
		    end
		end


		private

		def finish_booking_params
			params.require(:booking).permit(images_attributes: [:base64], provider_review_attributes: [ :body ] )
		end	
	end
end