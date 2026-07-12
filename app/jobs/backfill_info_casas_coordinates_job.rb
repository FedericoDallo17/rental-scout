class BackfillInfoCasasCoordinatesJob < ActiveJob::Base
  queue_as :default

  def perform(limit: nil, external_ids: nil)
    Scraping::BackfillInfoCasasCoordinates.new.call(limit:, external_ids:)
  end
end
