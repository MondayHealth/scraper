require_relative 'base'

module Jobs
  module Scrapers
    class AetnaScraper < Base
      def self.perform(plan_id, url)
        plan = Plan.find(plan_id)
        self.page_source_for_url(url)
      end
    end
  end
end