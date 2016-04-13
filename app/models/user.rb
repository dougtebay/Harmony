# == Schema Information
#
# Table name: users
#
#  id              :integer          not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  first_name      :string
#  last_name       :string
#  email           :string
#  password_digest :string
#

class User < ActiveRecord::Base
  has_many :prescriptions
  has_many :pharmacies, through: :prescriptions
  has_many :doctors, through: :prescriptions
  has_many :drugs, through: :prescriptions
  has_secure_password
  validates :first_name, :last_name, :email, presence: true

  def doctors_names
    my_docs = []
    self.doctors.collect do |d|
      my_docs << "#{d.id} - Dr. #{d.first_name} #{d.last_name} - #{d.location}"
    end
    my_docs.uniq
  end

  def pharmacy_names
    my_pharms = []
    self.pharmacies.collect do |p|
      my_pharms << "#{p.id} - #{p.name} - #{p.location}"
    end
    my_pharms.uniq
  end

  def active_prescriptions
    self.prescriptions.where("end_date >= ?", Date.today).where("start_date <= ?", Date.today)
  end

  def inactive_prescriptions
    self.prescriptions.where("end_date < ?", Date.today)
  end

  def active_prescriptions_day(date)
    # return an array of day's active prescription objects
     self.prescriptions.where("end_date >= ?", date)
  end

  def prescription_schedule_week
    # [{4/8/2016: [script 1, script2]},{4/9/2016: [script 1, script2]}...]
    today = Date.today
    schedule = []
    7.times do |i|
      schedule<< {(today + i) => active_prescriptions_day(today+i)}
    end
    schedule
  end

  def upcoming_refills
    # {script: refill date}
    # 7 days
    active_prescriptions.select do |p|
      (p.end_date < Date.today + 7) && (p.refills > 0 )
    end
  end

  def prescriptions_by_time_of_day(time_of_day)
    prescriptions = self.active_prescriptions.select do |prescription|
      prescription.scheduled_doses.map {|dose| dose.time_of_day}.include?(time_of_day)
    end
    render_prescriptions(prescriptions, time_of_day)
  end

  def render_prescriptions(prescriptions, time_of_day)
    prescriptions.map do |prescription|
      name = prescription.drug.name
      doses = prescription.scheduled_doses.select {|dose| dose.time_of_day == time_of_day}.count
      dose_size = prescription.dose_size
      interactions = get_interactions_by_drug(prescription.drug)
      associate_drug_names_with_interactions(interactions, prescription.drug)
      {name: name, doses: doses, dose_size: dose_size, interactions: interactions}
    end
  end

  def get_interactions_by_drug(drug)
    interactions = Interaction.joins(:drug_interactions).where("drug_id = ?", drug.id)
    interactions.reject {|interaction| interaction.description == "No interactions."}
  end

  def associate_drug_names_with_interactions(interactions, drug)
    interactions.map do |interaction|
      drug_interactions = DrugInteraction.all.select {|drug_interaction| drug_interaction.interaction_id == interaction.id}
      drug_interaction = drug_interactions.reject {|drug_interaction| drug_interaction.drug_id == drug.id}
      drug = Drug.find(drug_interaction[0].drug_id)
      {drug_name: drug.name, interaction: interaction.description}
    end
  end

  def active_drugs
    self.active_prescriptions.map do |prescription|
      prescription.drug
    end
  end

  def persist_drug_interactions(drug)
    drug_pairs = create_drug_pairs(drug)
    interactions_not_known = drug_pairs.reject {|drug_pair| drug_interaction_is_known?(drug_pair)}
    interactions_not_known.each do |drug_pair|
      interaction = Adapters::InteractionClient.interactions(drug_pair)
      interaction.save
      DrugInteraction.create(drug_id: drug_pair[0].id, interaction_id: interaction.id)
      DrugInteraction.create(drug_id: drug_pair[1].id, interaction_id: interaction.id)
    end
  end

  # Returns an array of arrays combining the drug from the argument with all other active drugs
  def create_drug_pairs(drug)
    drugs = self.active_drugs.reject {|d| d.name == drug.name}
    drugs.map {|d| [drug, d]}.uniq
  end

  # Checks whether both drugs passed in as arguments have already been recorded
  # in the drug interactions table and whether they share an interaction
  def drug_interaction_is_known?(drug_pair)
    DrugInteraction.find_by(drug_id: drug_pair[0].id) &&
    DrugInteraction.find_by(drug_id: drug_pair[1].id) &&
    DrugInteraction.find_by(drug_id: drug_pair[0].id).interaction_id ==
    DrugInteraction.find_by(drug_id: drug_pair[1].id).interaction_id
  end
end