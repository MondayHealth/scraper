module Jobs
  class ProviderRecordScanner
    def self.perform provider_id
      provider = Provider.find(provider_id)
      provider.provider_records.find_each do |provider_record|
        doctor = Doctor.where(first_name: provider_record.first_name, 
                              last_name: provider_record.last_name, 
                              license: provider_record.license).first
        if doctor.nil?
          create_doctor_from_provider_record!(provider_record)
        else
          # we'll need to flag the doctor for review here
        end
      end
    end

    def self.create_doctor_from_provider_record!(provider_record)
      Doctor.transaction do
        doctor = Doctor.where(first_name: provider_record.first_name, 
                              last_name: provider_record.last_name, 
                              license: provider_record.license).first_or_create!
        doctor.locations.where(address: provider_record.address).first_or_create! do |l|
          l.phone = provider_record.phone
        end
        provider_record.specialties.split(/;\s*/).each do |specialty_name|
          specialty = Specialty.where(name: specialty_name).first_or_create!
          doctor.specialties << specialty unless doctor.specialties.include?(specialty)
        end
      end
    end
  end
end
