module Jobs
  class ProviderRecordProcessor
    @queue = :scraper_provider_record_processor

    def self.perform(provider_record_id)
      provider_record = ProviderRecord.find(provider_record_id)
      provider = Provider.where(first_name: provider_record.first_name, 
                            last_name: provider_record.last_name, 
                            license: provider_record.license).first
      if provider.nil?
        STDOUT.puts "Creating new provider from provider record (#{provider_record.id})"
        create_provider_from_provider_record!(provider_record)
      else
        if provider_record.provider.nil?
          STDOUT.puts "Mapping provider record to provider #{provider.first_name} #{provider.last_name} (#{provider.id}) with link to provider record (#{provider_record.id})"
          provider_record.update_column('provider_id', provider.id) if provider_record.provider_id != provider.id
        end
      end
    end

    def self.create_provider_from_provider_record!(provider_record)
      Provider.transaction do
        provider = Provider.where(first_name: provider_record.first_name, 
                              last_name: provider_record.last_name, 
                              license: provider_record.license).first_or_create!
        addresses = provider_record.address.split("\n\n")
        phones = provider_record.phone.split("\n")
        addresses.each_with_index do |address, index|
          provider.locations.where(address: address).first_or_create! do |l|
            l.phone = phones[index] || phones.first
          end
        end
        provider_record.specialties.split(/;\s*/).each do |specialty_name|
          specialty = Specialty.where(name: specialty_name).first_or_create!
          provider.specialties << specialty unless provider.specialties.include?(specialty)
        end
        provider_record.update_column('provider_id', provider.id)
      end
    end

  end
end