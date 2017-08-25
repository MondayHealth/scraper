namespace :providers do
  desc "Refreshes providers with a full crawl"
  task :load => [:environment] do
    Provider.find_each do |provider|
      Jobs::CsvCleaner.perform("#{provider.name.downcase}.csv")
      Jobs::CsvLoader.perform("#{provider.name.downcase}.cleaned.csv")
      Jobs::ProviderRecordScanner.perform(provider.id)
    end
  end
end