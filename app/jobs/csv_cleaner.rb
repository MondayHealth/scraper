module Jobs
  class CsvCleaner
    def self.perform(path)
      unsorted_csv = CSV.read(path, headers: true)
      sorted_csv = unsorted_csv.sort_by { |row| [row['accepted_plan_ids'], row['first_name'], row['last_name']] }
      CSV.open(path + ".sorted", 'w+') do |csv|
        last_unique_row = nil
        sorted_csv.each_with_index do |row, index|
          skipping = false

          # if last unique row is nil
          last_unique_row ||= row

          # if we have a duplicate, add the next row's plans
          # and don't write to CSV
          if last_unique_row != row && duplicates?(last_unique_row, row)
            last_unique_row["accepted_plan_ids"] += ", " + row['accepted_plan_ids']
            skipping = true
          end

          is_last_row = index == sorted_csv.length - 1
          unless skipping && !is_last_row
            csv << last_unique_row
            last_unique_row = nil
          end
        end
      end
    end

    def self.duplicates?(row_1, row_2)
      row_1['first_name'] == row_2['first_name'] &&
      row_1['last_name'] == row_2['last_name'] &&
      row_1['accepted_plan_ids'] == row_2['accepted_plan_ids']
    end
  end
end