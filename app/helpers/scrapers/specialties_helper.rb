module Helpers
  module Scrapers
    module SpecialtiesHelper
      SPECIALTIES_AGE_RANGE_REGEXP = /(?:\s+\-\s+)?([0-9]+)\s*(?:(?:-|to)\s*([0-9]+)|and (?:older|up))/

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def normalize_specialty(name)
          normalized_name = name.strip
          # for anything other than the generic “Clinical X” specializations, 
          # we can discard the age range before storing the data.
          unless normalized_name =~ /^Clinical/
            return normalized_name.sub(SPECIALTIES_AGE_RANGE_REGEXP, '').strip
          end

          # if we find a match for the generic specialties, return them without 'Clinical'
          case normalized_name
          when /Child (?:&|and) Adolescent/i
            return 'Child & Adolescent'
          when /Geriatric/i
            return 'Geriatric'
          when /General Practice/i
            return 'General Practice'
          end

          # for the generic “Clinical X” specializations, we’ll map the age ranges 
          # to the three sub-specialties below, and can otherwise discard the age 
          # range before storing the data

          match_data = normalized_name.match(SPECIALTIES_AGE_RANGE_REGEXP)

          # If there's no age range match, we return 'General Practice'
          return 'General Practice' if match_data.nil?

          lower_age = match_data[1].to_i
          upper_age = match_data[2].to_i

          # covers the 'and older' case
          upper_age = 100 if match_data[2].nil?

          # 'Child & Adolescent' is any age range that falls exclusively into the 0-21 range, e.g. 13 to 17, 2 to 21, Newborn to 21, etc.
          # 'Geriatric' is any age range that starts from 60 and does not include any ages below that, e.g. 60 to 90, 65 and older, 66 to 90
          # 'General Practice' is any other age range, even if they include Child & Adolescent and Geriatric age ranges
          if upper_age <= 21
            return 'Child & Adolescent'
          elsif lower_age >= 60
            return 'Geriatric'
          else
            return 'General Practice'
          end
        end
      end
    end
  end
end