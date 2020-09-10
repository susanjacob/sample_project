class Api::BillsController < ApplicationController
  before_filter :check_session
  before_filter :check_business_date

  # Method to create bill for reservation / group / posting account
  def create
    # Get the associated reservation / group / posting account
    associated = fetch_associated_entity
    errors = []
    if associated.present?
      # bill_one will create bill with number 1 if no bill is present
      associated.bill_one if associated.bills.empty?
      # Create bill with number next increment to last one if not specified
      bill_number = params[:bill_number] ? params[:bill_number] : associated.bills.last.bill_number + 1
      bill = associated.bills.create(bill_number: bill_number)
      hotel = bill.associated.hotel
      # Log activities
      record_actions(hotel, associated, bill_number)
    else
      errors << I18n.t(:could_not_find_associated)
    end
    errors = bill.errors.full_messages
    render(json: errors, status: :unprocessable_entity) if errors.present?
  end

  # Get the polymorphic entity to which the bill is associated with
  def fetch_associated_entity
    if params[:entity_id].present? && params[:entity_type].present?
      if params[:entity_type] == Ref::PostingAccountType[:GROUP].value
        @group = Group.find(params[:entity_id])
        associated = group.posting_account
      end
    elsif params[:account_id]
      associated = PostingAccount.find(params[:account_id])
    elsif params[:reservation_id].present?
      associated = Reservation.find(params[:reservation_id])
    end
    associated
  end

  # Record activity log on relevant associated entities
  def record_actions(hotel, associated, bill_number)
    action_details = [
      { key: 'Bill Number', new_value: bill_number }
    ]
    Action.record!(@group, :CREATE_BILL, :ROVER, hotel.id, action_details) if @group.present?
    Action.record!(associated, :CREATE_BILL, :ROVER, hotel.id, action_details)
  end

end
