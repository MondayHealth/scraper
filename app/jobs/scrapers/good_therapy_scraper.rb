require_relative 'base'

module Jobs
  module Scrapers
    class GoodTherapyScraper < Base
      include Helpers::Scrapers::SpecialtiesHelper

      NAME_AND_LICENSE_REGEX = /\s((?:(?:[A-Z\-]\.|[A-Z\-]){2,})|Ph\.?D\.?|Psy\.?D\.?).*$/

      def self.perform(cache_key)
        directory = Directory.find_by(short_name: 'good-therapy')
        if directory.nil?
          raise MissingSourceError.new("Missing GoodTherapy Directory in database. Are you sure the seed data is there?")
        end
        doc = Nokogiri::HTML.parse(self.page_source_for_key(cache_key))
        csv_path = "#{ENV['STORAGE_DIRECTORY']}/good-therapy.csv"
        self.initialize_csv(csv_path)
        CSV.open(csv_path, 'a') do |csv|
          row = extract_provider(doc)
          if row
            row.unshift(nil) # no plan ID
            row.unshift(nil) # no payor ID
            row.unshift(directory.id)
            csv << row
          end
        end
      end

      def self.extract_provider doc
        row = []

        provider_name_and_license = strip_with_nbsp(doc.at_css('#profileTitle_id').content)
        provider_name_and_license.sub!(/^Dr.\s/, '')
        full_name = provider_name_and_license.sub(NAME_AND_LICENSE_REGEX, '')

        # since the comma is optional, it gets caught in the name for some records
        names = full_name.sub(/,$/, '').split(/\s+/).map(&:strip)

        provider_license_match = provider_name_and_license.match(NAME_AND_LICENSE_REGEX)
        provider_license = nil
        unless provider_license_match.nil?
          provider_license = provider_license_match.to_s.strip
        end
        row << names.first
        row << names[1..-1].join(" ")
        row << provider_license

        unless provider_license.nil? || valid_license_type?(provider_license)
          return nil
        end

        # multiple locations separated by double-line-breaksdd
        street_addresses = doc.css('div[itemprop="address"]').map do |div|
          # some addresses are missing critical data, so we'll do our best to dump what content
          # they have into an address field
          address = strip_with_nbsp(div.at_css('span[itemprop="streetAddress"]').andand.content)
          address2 = strip_with_nbsp(div.at_css('span[class*="address2"]').andand.content)
          city = strip_with_nbsp(div.at_css('span[itemprop="addressLocality"]').andand.content)
          state = strip_with_nbsp(div.at_css('span[itemprop="addressRegion"]').andand.content)
          zip = strip_with_nbsp(div.at_css('span[itemprop="postalCode"]').andand.content)

          # only include the final line if there's at least one city/state/zip
          address_last_line = (city || state || zip) ? "#{city}, #{state} #{zip}" : nil

          [address, address2, address_last_line].compact.join("\n")
        end
        street_addresses = street_addresses.join("\n\n")
        row << street_addresses

        phone = strip_with_nbsp(doc.at_css('.phone_profile_contact').content)
        row << phone

        specialties = doc.css('#issuesData li').map(&:content).map { |s| normalize_specialty(s) }.join(";")
        row << specialties

        row << nil # certificate_number
        row << nil # certified

        license_status = doc.at_css('#license_status_id').content.match(/[a-z]+ professional/).to_s
        row << license_status

        website_url = doc.at_css('#edit_website').andand['href']
        row << website_url

        primary_credential = strip_with_nbsp(doc.at_css('#licenceinfo1').andand.content)
        row << primary_credential
        
        professions = strip_with_nbsp(doc.at_css('#professionsDefined').content)
        row << professions

        # fees
        fees = doc.at_css('p:contains("Fees:")')
        unless fees.nil?
          fees = strip_with_nbsp(fees.content.sub('Fees:', '').sub('$', '')) 
          minimum_fee = fees.split(/\s*\-\s*/).first
          maximum_fee = fees.split(/\s*\-\s*/).last
        end
        row << minimum_fee
        row << maximum_fee

        sliding_scale = !doc.at_css('#sliding_scale.green-checkmark').nil?
        free_consultation = !doc.at_css('#free_initial_consultation.green-checkmark').nil?
        row << sliding_scale
        row << free_consultation

        # practice details
        services = extract_list_items_for_selector(doc, '#servicesprovidedData li')
        row << services
        languages = extract_list_items_for_selector(doc, '#languagesData li')
        row << languages
        modalities = extract_list_items_for_selector(doc, '#editModels li')
        row << modalities
        works_with_ages = extract_list_items_for_selector(doc, '#agesData li')
        row << works_with_ages
        works_with_groups = extract_list_items_for_selector(doc, '#groupsiworkwith li')
        row << works_with_groups
        
        # insurance
        accepted_payors = doc.css('#billingData li').map(&:content).join(";")
        row << accepted_payors

        row
      end

      def self.extract_list_items_for_selector doc, selector
        strip_with_nbsp(doc.css(selector).map(&:content).join(";"))
      end

    end
  end
end