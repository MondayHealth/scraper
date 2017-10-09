module Jobs
  class ProviderRecordScanner

    @queue = :scraper_provider_record_scanner

    def self.perform provider_record_ids
      provider_record_ids.each do |id|
        STDOUT.puts "Enqueueing Jobs::ProviderRecordProcessor with [#{id}]"
        Resque.enqueue(Jobs::ProviderRecordProcessor, id)
      end
    end
  end
end
