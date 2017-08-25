module Jobs
  class CsvCleaner
    def self.perform(path)
      unsorted_csv = CSV.read(path, headers: true)
      sorted_csv = unsorted_csv.sort_by { |row| [row['first_name'].to_s, row['last_name'].to_s, row['accepted_plan_ids']] }
      unique_csv = sorted_csv.uniq { |row| [row['first_name'].to_s, row['last_name'].to_s, row['accepted_plan_ids']] }
      new_path = path.sub(/\.csv$/, '.cleaned.csv')
      CSV.open(new_path, 'w+') do |csv|
        csv << Jobs::Scrapers::CSV_FIELDS
        last_unique_row = nil
        unique_csv.each_with_index do |row, index|
          last_unique_row ||= row
          plan_ids ||= []

          if last_unique_row != row && duplicates?(last_unique_row, row)
            # add the current accepted plan IDs to the previous line 
            last_unique_row["accepted_plan_ids"] = last_unique_row["accepted_plan_ids"] + ", " + row['accepted_plan_ids']
          end

          is_last_row = (index == sorted_csv.length - 1)
          # when we find a new record, or hit the end of the file, write to CSV
          if !duplicates?(last_unique_row, row) || is_last_row
            csv << last_unique_row
            last_unique_row = row
          end
        end
      end
    end

    def self.duplicates?(row_1, row_2)
      row_1['first_name'] == row_2['first_name'] &&
      row_1['last_name'] == row_2['last_name']
    end
  end
end