require "json"

module Zones
  class ImportMontevideoNeighborhoods
    SOURCE_KEY = "ide_uy_barrios_montevideo"
    SOURCE_URL = "https://mapas.ide.uy/geoserver-vectorial/ws_capa_base/wfs?service=WFS&version=2.0.0&request=GetFeature&typeNames=ws_capa_base%3Abarrios_montevideo&outputFormat=application%2Fjson&srsName=EPSG%3A4326"

    Result = Data.define(:created_count, :updated_count)

    def call(json:)
      collection = JSON.parse(json)
      raise ArgumentError, "expected a GeoJSON FeatureCollection" unless collection["type"] == "FeatureCollection"

      created_count = 0
      updated_count = 0

      Zone.transaction do
        collection.fetch("features").each do |feature|
          properties = feature.fetch("properties")
          name = canonical_name(properties.fetch("barrio"))
          feature_id = (properties["gid"] || properties["ogc_fid"]).to_s
          zone = Zone.find_or_initialize_by(source_key: SOURCE_KEY, source_feature_id: feature_id)
          zone = Zone.find_or_initialize_by(slug: name.parameterize) if zone.new_record? && Zone.exists?(slug: name.parameterize)
          was_new = zone.new_record?

          zone.assign_attributes(
            name:,
            slug: name.parameterize,
            aliases: (zone.aliases + aliases_for(name)).uniq,
            geom: geometry(feature.fetch("geometry")),
            active: true,
            source_key: SOURCE_KEY,
            source_url: SOURCE_URL,
            source_feature_id: feature_id
          )
          zone.save!
          was_new ? created_count += 1 : updated_count += 1
        end
      end

      Result.new(created_count:, updated_count:)
    end

    private

    def canonical_name(value)
      value.to_s.mb_chars.downcase.titleize.to_s
    end

    def aliases_for(name)
      aliases = [name.downcase, ActiveSupport::Inflector.transliterate(name).downcase]
      aliases << "villa del cerro" if name == "Cerro"
      aliases.uniq
    end

    def geometry(value)
      raise ArgumentError, "expected MultiPolygon geometry" unless value["type"] == "MultiPolygon"

      polygons = value.fetch("coordinates").map do |rings|
        exterior, *interiors = rings.map { |coordinates| linear_ring(coordinates) }
        Zone::FACTORY.polygon(exterior, interiors)
      end
      Zone::FACTORY.multi_polygon(polygons)
    end

    def linear_ring(coordinates)
      Zone::FACTORY.linear_ring(coordinates.map { |longitude, latitude| Zone::FACTORY.point(longitude, latitude) })
    end
  end
end
