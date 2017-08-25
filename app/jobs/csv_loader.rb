module Jobs
  class CsvLoader
    def self.perform(path)
      provider_records = []
      CSV.foreach(path, headers: true) do |row|
        provider_records << ProviderRecord.new(row.to_h)
      end
      columns = ProviderRecord.attribute_names
      columns.delete('id')
      options = { on_duplicate_key_update: { conflict_target: [:first_name, :last_name, :provider_id], columns: columns }}
      ProviderRecord.import(provider_records, options)
    end
  end
end