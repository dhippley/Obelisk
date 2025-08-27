-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create test database for running tests
CREATE DATABASE obelisk_test;
\c obelisk_test;
CREATE EXTENSION IF NOT EXISTS vector;
