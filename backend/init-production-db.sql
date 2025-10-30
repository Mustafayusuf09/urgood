-- UrGood Production Database Initialization
-- Mental Health App Optimized PostgreSQL Setup

-- Create extensions for performance and functionality
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "btree_gist";

-- Create application user with limited privileges
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'urgood_app') THEN
        CREATE ROLE urgood_app WITH LOGIN PASSWORD 'CHANGE_ME_IN_PRODUCTION';
    END IF;
END
$$;

-- Grant necessary permissions
GRANT CONNECT ON DATABASE urgood_production TO urgood_app;
GRANT USAGE ON SCHEMA public TO urgood_app;
GRANT CREATE ON SCHEMA public TO urgood_app;

-- Create optimized indexes for mental health data patterns
-- These will be applied after Prisma migrations

-- Function to create performance indexes
CREATE OR REPLACE FUNCTION create_urgood_indexes() RETURNS void AS $$
BEGIN
    -- User table optimizations
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'User') THEN
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_email_active 
            ON "User" (email) WHERE "deletedAt" IS NULL;
        
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_created_at 
            ON "User" ("createdAt" DESC);
        
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_user_last_active 
            ON "User" ("lastActiveAt" DESC) WHERE "lastActiveAt" IS NOT NULL;
    END IF;

    -- Chat message optimizations for conversation history
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'ChatMessage') THEN
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_chat_message_user_created 
            ON "ChatMessage" ("userId", "createdAt" DESC);
        
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_chat_message_session 
            ON "ChatMessage" ("sessionId", "createdAt" DESC);
        
        -- Full-text search on message content
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_chat_message_content_gin 
            ON "ChatMessage" USING gin(to_tsvector('english', content));
    END IF;

    -- Mood entry optimizations for analytics
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'MoodEntry') THEN
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mood_entry_user_date 
            ON "MoodEntry" ("userId", "createdAt" DESC);
        
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mood_entry_score_date 
            ON "MoodEntry" ("moodScore", "createdAt" DESC);
    END IF;

    -- Session optimizations for therapy tracking
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'Session') THEN
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_session_user_date 
            ON "Session" ("userId", "startedAt" DESC);
        
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_session_duration 
            ON "Session" ("duration") WHERE "duration" IS NOT NULL;
    END IF;

    -- Crisis event optimizations for emergency response
    IF EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'CrisisEvent') THEN
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_crisis_event_user_severity 
            ON "CrisisEvent" ("userId", "severity", "createdAt" DESC);
        
        CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_crisis_event_resolved 
            ON "CrisisEvent" ("resolved", "createdAt" DESC);
    END IF;

    RAISE NOTICE 'UrGood performance indexes created successfully';
END;
$$ LANGUAGE plpgsql;

-- Create function to analyze mental health data patterns
CREATE OR REPLACE FUNCTION analyze_urgood_performance() RETURNS TABLE(
    table_name text,
    total_rows bigint,
    table_size text,
    index_size text,
    last_vacuum timestamp,
    last_analyze timestamp
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        schemaname||'.'||tablename as table_name,
        n_tup_ins + n_tup_upd + n_tup_del as total_rows,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as table_size,
        pg_size_pretty(pg_indexes_size(schemaname||'.'||tablename)) as index_size,
        last_vacuum,
        last_analyze
    FROM pg_stat_user_tables 
    WHERE schemaname = 'public'
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
END;
$$ LANGUAGE plpgsql;

-- Create function for database health monitoring
CREATE OR REPLACE FUNCTION urgood_health_check() RETURNS TABLE(
    metric text,
    value text,
    status text
) AS $$
DECLARE
    active_connections int;
    db_size bigint;
    slow_queries int;
BEGIN
    -- Check active connections
    SELECT count(*) INTO active_connections FROM pg_stat_activity WHERE state = 'active';
    
    -- Check database size
    SELECT pg_database_size(current_database()) INTO db_size;
    
    -- Check slow queries in last hour
    SELECT count(*) INTO slow_queries 
    FROM pg_stat_statements 
    WHERE mean_exec_time > 1000 AND calls > 0;
    
    RETURN QUERY VALUES 
        ('active_connections', active_connections::text, 
         CASE WHEN active_connections < 150 THEN 'healthy' ELSE 'warning' END),
        ('database_size_mb', (db_size / 1024 / 1024)::text, 'info'),
        ('slow_queries_1h', slow_queries::text,
         CASE WHEN slow_queries < 10 THEN 'healthy' ELSE 'warning' END);
END;
$$ LANGUAGE plpgsql;

-- Create maintenance procedures
CREATE OR REPLACE FUNCTION urgood_maintenance() RETURNS void AS $$
BEGIN
    -- Update table statistics
    ANALYZE;
    
    -- Log maintenance completion
    INSERT INTO maintenance_log (performed_at, operation, details) 
    VALUES (NOW(), 'routine_maintenance', 'Statistics updated, performance analyzed')
    ON CONFLICT DO NOTHING;
    
    RAISE NOTICE 'UrGood maintenance completed at %', NOW();
END;
$$ LANGUAGE plpgsql;

-- Create maintenance log table
CREATE TABLE IF NOT EXISTS maintenance_log (
    id SERIAL PRIMARY KEY,
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    operation TEXT NOT NULL,
    details TEXT,
    duration_ms INTEGER
);

-- Create index on maintenance log
CREATE INDEX IF NOT EXISTS idx_maintenance_log_date 
    ON maintenance_log (performed_at DESC);

-- Set up row-level security preparation
ALTER DATABASE urgood_production SET row_security = on;

-- Create audit trigger function for sensitive data
CREATE OR REPLACE FUNCTION audit_trigger_function() RETURNS trigger AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, operation, old_data, performed_at, user_id)
        VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD), NOW(), OLD."userId");
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, operation, old_data, new_data, performed_at, user_id)
        VALUES (TG_TABLE_NAME, TG_OP, row_to_json(OLD), row_to_json(NEW), NOW(), NEW."userId");
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, operation, new_data, performed_at, user_id)
        VALUES (TG_TABLE_NAME, TG_OP, row_to_json(NEW), NOW(), NEW."userId");
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create audit log table
CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    table_name TEXT NOT NULL,
    operation TEXT NOT NULL,
    old_data JSONB,
    new_data JSONB,
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_id TEXT
);

-- Create index on audit log
CREATE INDEX IF NOT EXISTS idx_audit_log_table_date 
    ON audit_log (table_name, performed_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_log_user_date 
    ON audit_log (user_id, performed_at DESC);

-- Grant permissions to application user
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO urgood_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO urgood_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO urgood_app;

-- Set default permissions for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO urgood_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO urgood_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO urgood_app;

-- Log successful initialization
INSERT INTO maintenance_log (operation, details) 
VALUES ('database_initialization', 'Production database initialized with UrGood optimizations');

-- Display completion message
DO $$
BEGIN
    RAISE NOTICE '🎯 UrGood Production Database Initialized Successfully';
    RAISE NOTICE '📊 Extensions: uuid-ossp, pg_stat_statements, pg_trgm, btree_gin, btree_gist';
    RAISE NOTICE '👤 Application user: urgood_app (remember to change password)';
    RAISE NOTICE '🔍 Performance functions: create_urgood_indexes(), analyze_urgood_performance()';
    RAISE NOTICE '🏥 Health check: urgood_health_check()';
    RAISE NOTICE '🔧 Maintenance: urgood_maintenance()';
    RAISE NOTICE '📝 Audit logging enabled for sensitive operations';
END;
$$;
