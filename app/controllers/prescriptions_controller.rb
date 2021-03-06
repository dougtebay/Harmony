class PrescriptionsController < ApplicationController
  skip_before_action :authorized?

  def index
    @prescriptions = current_user.prescriptions.all
    @prescription = Prescription.new
    render :partial => "/prescriptions/index", :locals => { :prescriptions => @prescriptions }
  end

  def show
    @prescription = Prescription.find(params[:id])
  end

  def new
    @user = current_user
    @prescription = Prescription.new
    @prescription.drug = Drug.new
    @prescription.doctor = Doctor.new
    @prescription.pharmacy = Pharmacy.new
    render :partial => "/prescriptions/prescription_form",
    :locals => { :prescription => @prescription, :user => @user }
  end

  def edit
    @user = current_user
    @prescription = Prescription.find(params[:id])
    render :partial => "/prescriptions/prescription_form",
    :locals => { :prescription => @prescription, :user => @user }
  end

  def create
    @prescription = Prescription.new(prescription_params)
    @prescription.user = current_user
    find_or_create_drug
    @prescription.drug.persist_interactions(current_user)
    find_or_create_doctor
    find_or_create_pharmacy
    @prescription.save
    create_scheduled_doses
    @prescription.calculate_end_date
    @user = current_user
    if request.referer == "#{request.base_url}/users/#{current_user.id}"
      render :partial => "/users/show", :locals => { user: @user, prescription: @prescription }
    elsif request.referer == "#{request.base_url}/prescriptions"
      @prescriptions = current_user.prescriptions.all
      render :partial => "/prescriptions/index", :locals => { user: @user, prescription: @prescription }
    elsif request.referer == "#{request.base_url}/"
      render :partial => "/users/show", :locals => { user: @user, prescription: @prescription }
    end
  end

  def update
    @prescription = Prescription.find(params[:id])
    start_date = @prescription.start_date
    fill_duration = @prescription.fill_duration
    @prescription.update(prescription_params)
    find_or_create_doctor
    find_or_create_pharmacy
    @prescription.save
    @prescription.scheduled_doses.clear
    create_scheduled_doses
    if start_date != @prescription.start_date || fill_duration != @prescription.fill_duration
      @prescription.calculate_end_date
    end
    @prescriptions = current_user.prescriptions.all
    @user = current_user
    render :partial => "/users/show", :locals => { user: @user, prescription: @prescription }
  end

  def destroy
    @prescription = Prescription.find(params[:id])
    @prescription.destroy
    @prescriptions = current_user.prescriptions.all
    render :partial => "/prescriptions/index", :locals => { prescriptions: @prescriptions }
  end

  private

  def find_or_create_drug
    if Drug.find_by_name(drug_params[:name].capitalize)
      @prescription.drug = Drug.find_by_name(drug_params[:name].capitalize)
    else
      new_drug = Adapters::DrugClient.find_by_name(drug_params[:name])
      @prescription.drug = Drug.find_or_create_by({name: new_drug.name, rxcui: new_drug.rxcui})
    end
  end

  def find_or_create_doctor
    if params[:doctor_type] == "new"
      @prescription.doctor = Doctor.create(doctor_params)
    elsif params[:doctor][:id].length > 0
      @prescription.doctor = Doctor.find(params[:doctor][:id])
    end
  end

  def find_or_create_pharmacy
    if params[:pharmacy_type] == "new"
      @prescription.pharmacy = Pharmacy.create(pharmacy_params)
    elsif params[:pharmacy][:id].length > 0
      @prescription.pharmacy = Pharmacy.find(params[:pharmacy][:id])
    end
  end

  def create_scheduled_doses
    scheduled_doses_params.each do |time_of_day, count|
      count.to_i.times do
        ScheduledDose.create(time_of_day: time_of_day, prescription_id: @prescription.id)
      end
    end
  end

  def doctor_params
    params.require(:doctor).permit(:first_name, :last_name, :location)
  end

  def pharmacy_params
    params.require(:pharmacy).permit(:name, :location)
  end

  def drug_params
    params.require(:drug).permit(:name)
  end

  def prescription_params
    params.require(:prescription).permit(:fill_duration, :refills, :start_date, :dose_size)
  end

  def scheduled_doses_params
    params.require(:scheduled_doses).permit(:morning, :afternoon, :evening, :bedtime)
  end
end