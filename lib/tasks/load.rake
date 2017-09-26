namespace :payors do
  desc "Refreshes payors with a full crawl"
  task :load => [:environment] do
    Payor.find_each do |payor|
      Jobs::CsvCleaner.perform("#{ENV['STORAGE_DIRECTORY']}/#{payor.name.downcase}.csv")
      Jobs::CsvLoader.perform("#{ENV['STORAGE_DIRECTORY']}/#{payor.name.downcase}.cleaned.csv")
      Jobs::ProviderRecordScanner.perform(payor.id)
    end
  end
end