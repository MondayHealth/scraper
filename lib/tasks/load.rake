namespace :payors do
  desc "Updates provider records for all payors"
  task :load => [:environment] do
    Payor.find_each do |payor|
      Jobs::CsvCleaner.perform("#{ENV['STORAGE_DIRECTORY']}/#{payor.name.downcase}.csv")
      Jobs::CsvLoader.perform("#{ENV['STORAGE_DIRECTORY']}/#{payor.name.downcase}.cleaned.csv")
      payor.reload
      Jobs::ProviderRecordScanner.perform(payor.provider_records.pluck(:id))
    end
  end
end

namespace :directories do
  desc "Updates provider records for all directories"
  task :load => [:environment] do
    Directory.find_each do |directory|
      Jobs::CsvLoader.perform("#{ENV['STORAGE_DIRECTORY']}/#{directory.short_name.downcase}.csv")
      directory.reload
      Jobs::ProviderRecordScanner.perform(directory.provider_records.pluck(:id))
    end
  end
end