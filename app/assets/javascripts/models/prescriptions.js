app.prescription = {
  model: {
    all: [],
    new: (function () {
      var prescription = function Prescription(fill_duration, refills, start_date, dose_size, drug, doctor, pharmacy, user, id, end_date){
        this.drug = drug;
        this.fill_duration = fill_duration;
        this. refills = refills;
        this.start_date = start_date;
        this.dose_size = dose_size;
        this.id = id;
        this.doctor = doctor;
        this.pharmacy = pharmacy;
        this.user = user;
        this.end_date = end_date;
        app.prescription.model.all.push(this);
      };
      prescription.prototype.prescriptionEl = function() {
        return '<div ><div class="prescription-div-'+this.id+'"> \
        <a data-toggle="collapse" href="#collapsed-details-'+this.id+'" aria-expanded="false" aria-control="collapsed-details-'+this.id+'"> \
        <div class="prescription col-md-8 col-md-offset-2"> \
        <h2>'+this.drug.name+' <small id="prescription-'+this.id+'" drug-id="'+this.drug.id+'"> '+this.start_date+' </small></h2>'+this.detailsDiv()+'</div>';
      };
      prescription.prototype.detailsDiv = function(){
        return '<div class="collapse" id="collapsed-details-'+this.id+'"><p>Dose Size: '+this.dose_size+'</p> \
          <p>Refills: '+this.refills+'</p><p>Fill Duration: '+this.fill_duration+'</p> \
          <p>Start date: '+this.start_date+'</p><p>End date: '+this.end_date+'</p> \
          <p>Dr. '+this.doctor.first_name+ " "+this.doctor.last_name+'</p> \
          <p>Pharmacy: '+this.pharmacy.name+ " - " +this.pharmacy.location+'</p> \
          </a><button type="button" class="btn btn-default navbar-btn" data-toggle="modal" data-target="#editPrescriptionModal-'+this.id+'">Update</button></div></div></div>';
      };
      return prescription;
    }()),
  },
};