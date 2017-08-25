module Jobs
  class CsvLoader
    @queue = :scraper_csv_loader

    def self.perform(path)
      provider_records = []
      CSV.foreach(path, headers: true) do |row|
        provider_record = ProviderRecord.new(row.to_h)
        if provider_record.valid?
          provider_records << provider_record
        else
          STDOUT.write("Invalid provider record: #{row.inspect}")
        end
      end
      columns = ProviderRecord.attribute_names
      columns.delete('id')
      options = { on_duplicate_key_update: { conflict_target: [:first_name, :last_name, :provider_id], columns: columns }}
      ProviderRecord.import(provider_records, options)
    end
  end
end