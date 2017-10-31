namespace :payors do
  desc "Updates provider records for all payors"
  task :load => [:environment] do
    Payor.find_each do |payor|
      csv_filename = "#{ENV['STORAGE_DIRECTORY']}/#{payor.name.downcase}.csv"
      if File.exists?(csv_filename)
        STDOUT.puts("Cleaning CSV for payor #{payor.name} with ID #{payor.id}")
        Jobs::CsvCleaner.perform(csv_filename)
        STDOUT.puts("Loading CSV for payor #{payor.name} with ID #{payor.id}")
        Jobs::CsvLoader.perform(csv_filename.sub(/\.csv/, '.cleaned.csv'))
        payor.reload
        Jobs::ProviderRecordScanner.perform(payor.provider_records.pluck(:id))
      else
        STDOUT.puts("No CSV found for payor #{payor.name} with ID #{payor.id}")
      end
    end
  end
end

namespace :directories do
  desc "Updates provider records for all directories"
  task :load => [:environment] do
    Directory.find_each do |directory|
      csv_filename = "#{ENV['STORAGE_DIRECTORY']}/#{directory.short_name.downcase}.csv"
      if File.exists?(csv_filename)
        Jobs::CsvCleaner.perform(csv_filename)
        Jobs::CsvLoader.perform(csv_filename.sub(/\.csv/, '.cleaned.csv'))
        directory.reload
        Jobs::ProviderRecordScanner.perform(directory.provider_records.pluck(:id))
      end
    end
  end
end
