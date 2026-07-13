require "net/http"

namespace :zones do
  desc "Import authoritative Montevideo neighborhood boundaries from IDE Uruguay"
  task import_montevideo: :environment do
    uri = URI(Zones::ImportMontevideoNeighborhoods::SOURCE_URL)
    response = Net::HTTP.get_response(uri)
    response.value
    result = Zones::ImportMontevideoNeighborhoods.new.call(json: response.body)
    puts "Montevideo neighborhoods imported: #{result.created_count} created, #{result.updated_count} updated"
  end
end
