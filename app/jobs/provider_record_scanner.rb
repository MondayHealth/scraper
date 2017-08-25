module Jobs
  class ProviderRecordScanner

    @queue = :scraper_provider_record_scanner

    def self.perform provider_id
      provider = Provider.find(provider_id)
      provider.provider_records.find_each do |provider_record|
        STDOUT.puts "Enqueueing Jobs::ProviderRecordProcessor with [#{provider_record.id}]"
        Resque.enqueue(Jobs::ProviderRecordProcessor, provider_record.id)
      end
    end
  end
end
