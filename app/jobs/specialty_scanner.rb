module Jobs
  class SpecialtyScanner

    @queue = :scraper_specialty_scanner

    def self.perform path
      CSV.foreach(path, headers: true) do |row|
        STDOUT.puts "Checking specialty #{row["name"]} for alias #{row["alias"]}"
        specialty = Specialty.find_by(name: row["name"])
        if specialty && specialty.alias.nil?
          canonical_alias = Specialty.where(name: row["alias"]).first_or_create!
          canonical_alias.is_canonical = true
          canonical_alias.save! if canonical_alias.changed?
          specialty.alias = canonical_alias
          specialty.save!
          STDOUT.puts "Mapped specialty #{row["name"]} to alias #{row["alias"]}"
        end
      end
    end
  end
end
