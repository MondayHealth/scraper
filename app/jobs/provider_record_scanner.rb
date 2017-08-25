module Jobs
  class ProviderRecordScanner
    def self.perform provider_id
      provider = Provider.find(provider_id)
      provider.provider_records.find_each do |provider_record|
        STDOUT.puts "Scanning provider record (#{provider_record.id})"
        doctor = Doctor.where(first_name: provider_record.first_name, 
                              last_name: provider_record.last_name, 
                              license: provider_record.license).first
        if doctor.nil?
          STDOUT.puts "Creating new doctor from provider record (#{provider_record.id})"
          create_doctor_from_provider_record!(provider_record)
        else
          STDOUT.puts "Updating doctor #{doctor.first_name} #{doctor.last_name} (#{doctor.id}) with link to provider record (#{provider_record.id})"
          provider_record.update_column('doctor_id', doctor.id) if provider_record.doctor_id != doctor.id
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
        provider_record.update_column('doctor_id', doctor.id)
      end
    end
  end
end
