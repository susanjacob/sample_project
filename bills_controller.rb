class Api::BillsController < ApplicationController
  before_filter :check_session
  before_filter :check_business_date

  # Method to create bill for reservation
  def create
    if params[:entity_id].present? && params[:entity_type].present?
      if params[:entity_type] == Ref::PostingAccountType[:GROUP].value
        group = Group.find(params[:entity_id])
        associated = group.posting_account
      end
    elsif params[:account_id]
      associated = PostingAccount.find(params[:account_id])
    elsif params[:reservation_id].present?
      associated = Reservation.find(params[:reservation_id])
    else
      render(json: [], status: :unprocessable_entity)
    end
    associated.bills.create(bill_number: 1) if associated.bills.empty?
    if params[:bill_number].present?
      @bill = associated.bills.create(bill_number: params[:bill_number])
    else
      @bill = associated.bills.create(bill_number: associated.bills.last.bill_number + 1)
    end
    action_details = [
      { key: 'Bill Number', old_value: nil, new_value: @bill.bill_number }
    ]
    if params[:account_id]
      if group.present?
        Action.record!(group, :CREATE_BILL, :ROVER, @bill.associated.hotel.id, action_details)
        Action.record!(associated, :CREATE_BILL, :ROVER, @bill.associated.hotel.id, action_details)
      else
        Action.record!(associated, :CREATE_BILL, :ROVER, @bill.associated.hotel.id, action_details)
      end
    else
      Action.record!(associated, :CREATE_BILL, :ROVER, @bill.associated.hotel.id, action_details)
    end
    render(json: @bill.errors.full_messages, status: :unprocessable_entity) unless @bill.errors.empty?
  end

end
