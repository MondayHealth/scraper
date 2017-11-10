module Jobs
  class CsvCleaner
    @queue = :scraper_csv_cleaner

    def self.perform(path)
      unsorted_csv = CSV.read(path, headers: true)
      sorted_csv = unsorted_csv.sort_by { |row| [row['first_name'].to_s, row['last_name'].to_s, row['accepted_plan_ids'], row['specialties'], row['certificate_number']] }
      unique_csv = sorted_csv.uniq { |row| [row['first_name'].to_s, row['last_name'].to_s, row['accepted_plan_ids'], row['specialties'], row['certificate_number']] }
      new_path = path.sub(/\.csv$/, '.cleaned.csv')
      puts "New Path: #{new_path}"
      CSV.open(new_path, 'w+') do |csv|
        csv << unsorted_csv.headers
        last_unique_row = nil
        unique_csv.each_with_index do |row, index|
          last_unique_row ||= row
          plan_ids ||= []

          if last_unique_row != row && duplicates?(last_unique_row, row)
            # add the current values for keys whose values might be duplicated to the previous line 
            ['accepted_plan_ids', 'specialties', 'certificate_number'].each do |dedupe_key|
              unless row[dedupe_key].nil?
                # since we might have searched by specialty for different plans, or by plan for different specialties,
                # we'll get duplicates values when we merge the duplicate rows unless we check first
                existing_values = last_unique_row[dedupe_key].split(";")
                unless existing_values.include?(row[dedupe_key])
                  last_unique_row[dedupe_key] = last_unique_row[dedupe_key] + ";" + row[dedupe_key]
                end
              end
            end
          end

          is_last_row = (index == sorted_csv.length - 1)
          # when we find a new record, or hit the end of the file, write to CSV
          if !duplicates?(last_unique_row, row) || is_last_row
            csv << last_unique_row
            last_unique_row = row
          end
          # if we hit the end of the file and didn't find a dupe before, write one more line
          if !duplicates?(last_unique_row, row) || is_last_row
            csv << row
          end
        end
      end
      FileUtils.mv(path, path.sub(/\.csv$/, ".#{Time.now.strftime('%F-%H-%M-%S')}.csv"))
    end

    def self.duplicates?(row_1, row_2)
      row_1['first_name'] == row_2['first_name'] &&
      row_1['last_name'] == row_2['last_name']
    end
  end
end