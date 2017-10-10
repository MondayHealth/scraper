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
          STDOUT.puts("Invalid provider record: #{row.inspect}")
          STDOUT.puts(provider_record.errors.inspect)
        end
      end
      columns = ProviderRecord.attribute_names
      columns.delete('id')
      columns.delete('created_at')
      columns.delete('updated_at')
      options = { on_duplicate_key_update: { conflict_target: [:first_name, :last_name, :payor_id, :directory_id], columns: columns }}
      ProviderRecord.import(provider_records, options)
      File.mv(path, path.sub(/\.csv$/, ".#{Time.now.strftime('%F-%H-%M-%S')}.csv"))
    end
  end
end