class Zone < ApplicationRecord
  FACTORY = RGeo::Geographic.spherical_factory(srid: 4326)

  has_many :search_zones, dependent: :destroy
  has_many :search_preferences, through: :search_zones

  validates :name, :slug, :geom, presence: true
  validates :slug, uniqueness: true

  before_validation :normalize_aliases

  def self.polygon_from_coordinates(coordinates)
    points = coordinates.map { |lng, lat| FACTORY.point(lng, lat) }
    FACTORY.multi_polygon([FACTORY.polygon(FACTORY.linear_ring(points))])
  end

  private

  def normalize_aliases
    self.aliases = aliases.map { |value| value.to_s.strip.downcase }.reject(&:blank?).uniq
  end
end
