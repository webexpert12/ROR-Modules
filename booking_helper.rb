module BookingHelper
	include ActionView::Helpers::NumberHelper
	
	def total_inspections_cost_setting(unit = nil)
		ic  = Setting.get_as_hash(:inspection_cost)
		"#{number_to_currency(ic.fetch(:total_inspection_cost , 79), :unit => unit || ic.fetch(:currency_unit , '€') ) }".gsub(/\.00$/, "")
	end

	def total_inspections_cost_setting_number
		ic  = Setting.get_as_hash(:inspection_cost)
		ic.fetch(:total_inspection_cost , 79)
	end

	def bookig_inspections_cost_setting(unit = nil)
		ic  = Setting.get_as_hash(:inspection_cost)
		"#{number_to_currency(ic.fetch(:booking_cost , 29), :unit => unit || ic.fetch(:currency_unit , '€') ) }".gsub(/\.00$/, "")
	end

	def payable_after_inspections_cost_setting(unit = nil)
		ic  = Setting.get_as_hash(:inspection_cost)
		"#{number_to_currency(ic.fetch(:total_inspection_cost , 79).to_i - ic.fetch(:booking_cost , 29).to_i , :unit => unit || ic.fetch(:currency_unit , '€') ) }".gsub(/\.00$/, "")
	end

	def step_indicator booking
		raise "instance of booking is needed" unless booking.is_a? Booking 
		
		level = Booking.all_states.to_h.collect.with_index { |s,i| (i) if (booking.state).in?(s[1]) }.compact.first
		['<div class="step-indicator hidden-md-down">',
			Booking.all_states.collect.with_index do |option, i|
				"<a class='step #{ i <= level ? 'completed' : ''}' href='javascript:void(0)'> #{option[0]}</a>"
			end,
		'</div>'].flatten
		.join.html_safe
	end

end