namespace :specialties do
  desc "Batch assigns specialties to their aliases from a CSV"
  task :assign_aliases => [:environment] do
    if ARGV[1].to_s.empty?
      puts "Usage: rake specialties:assign_aliases <INPUT_CSV>" 
      exit 1
    end
    Jobs::SpecialtyScanner.perform ARGV[1]
  end
end