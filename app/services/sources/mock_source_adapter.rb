module Sources
  class MockSourceAdapter
    LISTINGS = [
      {
        external_id: "mock-pocitos-2d-01",
        title: "Apartamento de 2 dormitorios con terraza en Pocitos",
        canonical_url: "https://example.test/listings/mock-pocitos-2d-01",
        location_text: "Pocitos, Montevideo",
        price_cents: 3_250_000,
        bedrooms: 2,
        square_meters: 58,
        description: "Living luminoso, cocina definida y terraza al frente a pocas cuadras de la rambla"
      },
      {
        external_id: "mock-cordon-1d-02",
        title: "Apartamento de 1 dormitorio reciclado en Cordón",
        canonical_url: "https://example.test/listings/mock-cordon-1d-02",
        location_text: "Cordón, Montevideo",
        price_cents: 2_180_000,
        bedrooms: 1,
        square_meters: 41,
        description: "Unidad reciclada con buena luz natural y conexión rápida al Centro y Tres Cruces"
      },
      {
        external_id: "mock-centro-studio-03",
        title: "Monoambiente amplio cerca de Plaza Cagancha",
        canonical_url: "https://example.test/listings/mock-centro-studio-03",
        location_text: "Centro, Montevideo",
        price_cents: 1_790_000,
        bedrooms: 0,
        square_meters: 33,
        description: "Espacio bien resuelto con kitchenette y buena locomoción en el corazón del Centro"
      },
      {
        external_id: "mock-parque-rodo-2d-04",
        title: "Apartamento de 2 dormitorios a pasos del parque",
        canonical_url: "https://example.test/listings/mock-parque-rodo-2d-04",
        location_text: "Parque Rodó, Montevideo",
        price_cents: 3_480_000,
        bedrooms: 2,
        square_meters: 64,
        description: "Planta cómoda con balcón, placares y cercanía a facultades, rambla y servicios"
      },
      {
        external_id: "mock-tres-cruces-1d-05",
        title: "Apartamento funcional de 1 dormitorio en Tres Cruces",
        canonical_url: "https://example.test/listings/mock-tres-cruces-1d-05",
        location_text: "Tres Cruces, Montevideo",
        price_cents: 2_240_000,
        bedrooms: 1,
        square_meters: 44,
        description: "Ideal para moverse por toda la ciudad, con cocina integrada y dormitorio definido"
      },
      {
        external_id: "mock-malvin-3d-06",
        title: "Apartamento familiar de 3 dormitorios en Malvín",
        canonical_url: "https://example.test/listings/mock-malvin-3d-06",
        location_text: "Malvín, Montevideo",
        price_cents: 4_650_000,
        bedrooms: 3,
        square_meters: 89,
        description: "Unidad espaciosa con vista despejada, lavadero y ambientes cómodos cerca de la costa"
      },
      {
        external_id: "mock-buceo-2d-07",
        title: "Apartamento de 2 dormitorios con garage en Buceo",
        canonical_url: "https://example.test/listings/mock-buceo-2d-07",
        location_text: "Buceo, Montevideo",
        price_cents: 3_950_000,
        bedrooms: 2,
        square_meters: 70,
        description: "Edificio moderno con ascensor, garage fijo y acceso rápido a WTC y la rambla"
      },
      {
        external_id: "mock-punta-carretas-1d-08",
        title: "Apartamento de 1 dormitorio en Punta Carretas",
        canonical_url: "https://example.test/listings/mock-punta-carretas-1d-08",
        location_text: "Punta Carretas, Montevideo",
        price_cents: 3_120_000,
        bedrooms: 1,
        square_meters: 47,
        description: "Buen metraje para un dormitorio, balcón al frente y servicios a pocas cuadras"
      },
      {
        external_id: "mock-pocitos-nuevo-2d-09",
        title: "Apartamento de 2 dormitorios en Pocitos Nuevo",
        canonical_url: "https://example.test/listings/mock-pocitos-nuevo-2d-09",
        location_text: "Pocitos Nuevo, Montevideo",
        price_cents: 3_680_000,
        bedrooms: 2,
        square_meters: 62,
        description: "Living comedor cómodo, cocina semi integrada y buena conexión con Rivera y la rambla"
      },
      {
        external_id: "mock-cordon-sur-1d-10",
        title: "Apartamento de 1 dormitorio en Cordón Sur",
        canonical_url: "https://example.test/listings/mock-cordon-sur-1d-10",
        location_text: "Cordón Sur, Montevideo",
        price_cents: 2_560_000,
        bedrooms: 1,
        square_meters: 46,
        description: "Opción práctica para estudiantes o profesionales, cerca de facultades y servicios"
      }
    ].freeze

 def fetch_listings
 LISTINGS.map do |listing|
 duplicated = listing.transform_values { |value| value.is_a?(String) ? value.dup : value }
 duplicated.merge(
 source_neighborhood: duplicated[:location_text].split(",").first.strip,
 source_city: "Montevideo",
 operation_type: "alquiler"
 )
 end
 end
  end
end
