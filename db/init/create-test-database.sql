-- Runs only the first time the db-data volume is created.
-- The test suite uses its own database so it never touches development data.
CREATE DATABASE "fudo-challenge-test";
