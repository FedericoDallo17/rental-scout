CREATE DATABASE rental_scout_lite_production_cache;
CREATE DATABASE rental_scout_lite_production_queue;
CREATE DATABASE rental_scout_lite_production_cable;

\connect rental_scout_lite_production
CREATE EXTENSION IF NOT EXISTS postgis;

\connect rental_scout_lite_production_cache
CREATE EXTENSION IF NOT EXISTS postgis;

\connect rental_scout_lite_production_queue
CREATE EXTENSION IF NOT EXISTS postgis;

\connect rental_scout_lite_production_cable
CREATE EXTENSION IF NOT EXISTS postgis;
