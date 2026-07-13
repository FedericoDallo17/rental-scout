# City-Wide Sources and Authoritative Neighborhoods Design

Provider requests cover Montevideo rather than Pocitos. Provider location metadata is
a fallback, never an invented default. The official IDE Uruguay `barrios_montevideo`
WFS layer supplies versionable EPSG:4326 polygons with source provenance. Coordinates
select the authoritative polygon; provider address text remains stored separately.

The runs workbench reports inventory location quality: spatially resolved, provider
fallback, unresolved, and spatial records whose preserved provider neighborhood
disagrees with the authoritative polygon. Metrics are aggregate diagnostics and do not
expose another user's searches or notification results.
