require_relative 'base'

module Jobs
  module Scrapers
    class PsychologyTodayScraper < Base
      include Helpers::Scrapers::SpecialtiesHelper

      CSV_FIELDS = ['directory_id',
                    'first_name',
                    'last_name',
                    'license',
                    'address',
                    'phone',
                    'website_url',
                    'languages',
                    'works_with_ages',
                    'works_with_groups',
                    'treatment_orientations',
                    'modalities',
                    'years_in_practice',
                    'school',
                    'year_graduated',
                    'license_number',
                    'license_state',
                    'minimum_fee',
                    'maximum_fee',
                    'sliding_scale',
                    'accepted_payment_methods',
                    'accepted_payors',
                    'source_updated_at']

      def self.perform(cache_key)
        directory = Directory.find_by(short_name: 'psych-today')
        if directory.nil?
          raise MissingSourceError.new("Missing PsychologyToday Directory in database. Are you sure the seed data is there?")
        end
        doc = Nokogiri::HTML.parse(self.page_source_for_key(cache_key))
        csv_path = "#{ENV['STORAGE_DIRECTORY']}/psychologytoday.csv"
        self.initialize_csv(csv_path, CSV_FIELDS)
        CSV.open(csv_path, 'a') do |csv|
          row = extract_provider(doc)
          if row
            row.unshift(directory.id)
            csv << row
          end
        end
      end

      def self.extract_provider doc
        row = []

        full_name = strip_with_nbsp(doc.at_css('h1[itemprop="name"]').text.gsub(/\s+/, " "))
        first_name = full_name.split(/\s+/)[0...-1].join(" ")
        row << first_name
        
        last_name = full_name.split(/\s+/).last
        row << last_name

        provider_license = strip_with_nbsp(doc.at_css('.profile-title').text.strip.gsub(/\s+/, " "))
        row << provider_license

        streetAddress = strip_with_nbsp(doc.at_css('.profile-address span[itemprop="streetAddress"]').inner_html.gsub(/<br\/?>/, "\n"))
        city = strip_with_nbsp(doc.at_css('.profile-address span[itemprop="addressLocality"]').text)
        state = strip_with_nbsp(doc.at_css('.profile-address span[itemprop="addressRegion"]').text)
        zip = strip_with_nbsp(doc.at_css('.profile-address span[itemprop="postalcode"]').text)
        address = [streetAddress, "#{city}, #{state} #{zip}"].join("\n")
        row << address

        phone = strip_with_nbsp(doc.at_css('.profile-address a[data-event-label="Address1_PhoneLink"]').text)
        row << phone

        website_url = doc.at_css('a[data-event-label="website"]').andand['href']
        row << website_url

        specialties = doc.css('.spec-list ul li').map(&:text).map { |s| normalize_specialty(s) }.join(";")
        row << specialties

        languages = extract_spans(doc, "Alternative Languages")
        row << languages

        works_with_ages = extract_list_items(doc, "Age")
        row << works_with_ages

        ethnicities = extract_spans(doc, "Ethnicity")
        religious_orientations = extract_spans(doc, "Religious Orientation")
        categories = extract_list_items(doc, "Categories")
        works_with_groups = [ethnicities, religious_orientations, categories].compact.join(";")
        row << works_with_groups

        treatment_orientations = extract_list_items(doc, "Treatment Orientation")
        row << treatment_orientations

        modalities = extract_list_items(doc, "Modality")
        row << modalities

        years_in_practice = extract_spans(doc, "Years in Practice")
        row << years_in_practice

        school = extract_spans(doc, "School")
        row << school

        year_graduated = extract_spans(doc, "Year Graduated")
        row << year_graduated

        license_number_and_state = extract_spans(doc, "License No. and State")
        license_number = license_number_and_state.match(/[0-9]+/).to_s
        row << license_number

        license_state = license_number_and_state.sub(/[0-9]+\s*/, '')
        row << license_state

        fees = extract_spans(doc, "Avg Cost (per session)")
        if fees_match = fees.match(/\$([0-9]{2,})\s*-\s*\$([0-9]{2,})/)
          minimum_fee = fees_match[1]
          maximum_fee = fees_match[2]
          row << minimum_fee
          row << maximum_fee
        else
          row << nil
          row << nil
        end

        sliding_scale = extract_spans(doc, "Sliding Scale") == 'Yes'
        row << sliding_scale

        accepted_payment_methods = extract_spans(doc, "Accepted Payment Methods")
        row << accepted_payment_methods

        accepted_payors = doc.css("strong:contains('Accepted Insurance Plans') + .spec-list li").map(&:text).map(&:strip).join(";")
        row << accepted_payors

        source_updated_at_string = doc.at_css('.last-modified').text.sub('Last Modified: ', '')
        source_updated_at = Time.parse(source_updated_at_string)
        row << source_updated_at

        row
      end

      def self.extract_spans doc, header_title
        node = doc.at_css("strong:contains('#{header_title}')")
        return nil if node.nil?
        node.parent.text.strip.sub("#{header_title}: ", '').gsub(/,\s*/, ';')
      end

      def self.extract_list_items doc, header_title
        nodes = doc.css("h3:contains('#{header_title}') + .row li")
        return nil if nodes.empty?
        nodes.map(&:text).map(&:strip).join(";")
      end

    end
  end
end