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

      # conflict_target does not play nicely with NULL, and allows duplicate rows
      # because SQL doesn't assume NULLs are equal, so we need to sniff for which
      # belongs_to ID is filled out and use that in the "upsert" query below
      # https://www.postgresql.org/docs/current/static/ddl-constraints.html#idm46046890694560
      conflict_target = nil
      if provider_records.last.payor_id.nil?
        provider_records = provider_records.uniq { |record| "#{record.first_name}_#{record.last_name}_#{record.directory_id}" }
        conflict_target = [:first_name, :last_name, :directory_id]
      else
      provider_records = provider_records.uniq { |record| "#{record.first_name}_#{record.last_name}_#{record.payor_id}" }
      conflict_target = [:first_name, :last_name, :payor_id]
      end
      options = { on_duplicate_key_update: { conflict_target: conflict_target, columns: columns }}
      ProviderRecord.import(provider_records, options)
      FileUtils.mv(path, path.sub(/\.csv$/, ".#{Time.now.strftime('%F-%H-%M-%S')}.csv"))
    end
  end
end