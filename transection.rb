class Transection < ApplicationRecord

  belongs_to :transectionable, :polymorphic => true
  register_currency :eur
  
  before_create :set_valid_amount
  monetize :amount_cents
  monetize :tax_cents
  monetize :total_cents
  validates_length_of :message, :minimum => 5


  #
  #scopes
  #
  scope :users_transections, -> (user_id){
    where(
    %{
        transections.id IN ( 
          SELECT transections.id from transections INNER JOIN wallets ON wallets.id = transections.transectionable_id 
          WHERE wallets.user_id = '#{user_id}'
          AND transections.transectionable_type IN ('Wallet')
          AND transections.deleted_at IS NULL 
        ) 
        OR 
        transections.id IN (
          SELECT transections.id from transections INNER JOIN withdraw_requests ON withdraw_requests.id = transections.transectionable_id 
          WHERE withdraw_requests.user_id = '#{user_id}'
          AND transections.transectionable_type IN ('WithdrawRequest')
          AND transections.deleted_at IS NULL
        )
    })
  }

  scope :booking_transections, -> { where(transectionable_type: "Booking") }
  scope :created_between, lambda {|start_date, end_date| where("created_at >= ? AND created_at <= ?", start_date, end_date ).sort_by {|x| [x.transectionable_id, x.transectionable_id] }}

  def self.all_status
  	{
  		initialized: 1,
  		success: 2,
  		failed: 3,
      approved: 4,
      rejected: 5,
      requested: 6,

  	}
  end
  
  private
  def set_valid_amount
  	self.amount = self.total - self.tax 
  end

end