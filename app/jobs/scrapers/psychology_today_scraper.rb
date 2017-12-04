require_relative 'base'
require 'curb'

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
                    'specialties',
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
        csv_path = "#{ENV['STORAGE_DIRECTORY']}/#{directory.short_name}.csv"
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

        # pages have two identical address wrappers for some reason
        first_address_wrapper = doc.at_css('.profile-address')
        address = first_address_wrapper.css('div[itemprop="address"]').map do |address_div|
          streetAddress = strip_with_nbsp(address_div.at_css('span[itemprop="streetAddress"]').andand.inner_html.andand.gsub(/<br\/?>/, "\n"))
          city = strip_with_nbsp(address_div.at_css('span[itemprop="addressLocality"]').text)
          state = strip_with_nbsp(address_div.at_css('span[itemprop="addressRegion"]').text)
          zip = strip_with_nbsp(address_div.at_css('span[itemprop="postalcode"]').text)
          [streetAddress, "#{city}, #{state} #{zip}"].compact.join("\n")
        end.join("\n\n")
        row << address

        phone = first_address_wrapper.css('div[itemprop="address"]').map do |phone_div|
          strip_with_nbsp(phone_div.at_css('a[data-event-label$="_PhoneLink"]').andand.text).andand.strip
        end.join("\n")
        row << phone

        website_url = doc.at_css('a[data-event-label="website"]').andand['href']
        redirect_url = website_url

        if website_url && !ENV['POLIPO_PROXY'].to_s.empty?
          with_retries(max_tries: 5, rescue: Curl::Err::CurlError) do
            # the site sends the user to a redirect URL, so pull that first
            response = Curl::Easy.http_get(website_url) do |curl|  
              curl.proxy_tunnel = true
              curl.proxy_url = ENV['POLIPO_PROXY']
              curl.follow_location = false
              curl.ssl_verify_peer = false
            end
            http_response, *http_headers = response.header_str.split(/[\r\n]+/).map(&:strip)
            http_headers = Hash[http_headers.flat_map{ |s| s.scan(/^(\S+): (.+)/) }]
            redirect_url = http_headers["location"]
          end
        end
        row << redirect_url

        specialties_selector = ['attributes-top', 'attributes-issues', 'attributes-mental-health', 'attributes-sexuality'].map do |selector|
          ".spec-list.#{selector} ul li"
        end.join(",")
        specialties = doc.css(specialties_selector).map(&:text).map { |s| normalize_specialty(s) }.join(";")
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

        # Some providers are interns, and have no license info as of yet, so we
        # drop their records from the scrape
        if license_number_and_state.nil?
            return nil
        end
        license_number = license_number_and_state.match(/([0-9]\s*)+/).to_s.strip
        row << license_number

        license_state = license_number_and_state.match(/([a-z]+\s*)+$/i).to_s.strip
        row << license_state

        fees = extract_spans(doc, "Avg Cost (per session)")
        if fees_match = fees.andand.match(/\$([0-9]{2,})\s*-\s*\$([0-9]{2,})/)
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

        accepted_payors = doc.css("h3:contains('Accepted Insurance Plans') + div li").map(&:text).map(&:strip).join(";")
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
        nodes = doc.css("h3:contains('#{header_title}') + * li")
        return nil if nodes.empty?
        nodes.map(&:text).map(&:strip).join(";")
      end

    end
  end
end