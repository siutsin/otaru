CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SCHEMA IF NOT EXISTS nuq;

DO $$ BEGIN
  CREATE TYPE nuq.job_status AS ENUM ('queued', 'active', 'completed', 'failed');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE nuq.group_status AS ENUM ('active', 'completed', 'cancelled');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS nuq.queue_scrape (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  status nuq.job_status NOT NULL DEFAULT 'queued'::nuq.job_status,
  data jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  priority int NOT NULL DEFAULT 0,
  lock uuid,
  locked_at timestamp with time zone,
  stalls integer,
  finished_at timestamp with time zone,
  listen_channel_id text, -- for listenable jobs over rabbitmq
  returnvalue jsonb, -- only for selfhost
  failedreason text, -- only for selfhost
  owner_id uuid,
  group_id uuid,
  CONSTRAINT queue_scrape_pkey PRIMARY KEY (id)
);

ALTER TABLE nuq.queue_scrape
SET (autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_analyze_scale_factor = 0.01,
    autovacuum_vacuum_cost_limit = 10000,
    autovacuum_vacuum_cost_delay = 0);

CREATE INDEX IF NOT EXISTS queue_scrape_active_locked_at_idx ON nuq.queue_scrape USING btree (locked_at) WHERE (status =
  'active'::nuq.job_status);
CREATE INDEX IF NOT EXISTS nuq_queue_scrape_queued_optimal_2_idx ON nuq.queue_scrape (priority ASC, created_at ASC, id) WHERE (status =
  'queued'::nuq.job_status);
CREATE INDEX IF NOT EXISTS nuq_queue_scrape_failed_created_at_idx ON nuq.queue_scrape USING btree (created_at) WHERE (status =
  'failed'::nuq.job_status);

-- Predicate-matching partial indexes for the standalone (group_id IS NULL)
-- cleaners. In production virtually every row has a group_id, so these
-- indexes stay tiny and turn the standalone cleaners into fast no-ops instead
-- of seq scans over the whole 18M-row table.
CREATE INDEX IF NOT EXISTS nuq_queue_scrape_completed_standalone_created_at_idx ON nuq.queue_scrape USING btree (created_at) WHERE (status =
  'completed'::nuq.job_status AND group_id IS NULL);
CREATE INDEX IF NOT EXISTS nuq_queue_scrape_failed_standalone_created_at_idx ON nuq.queue_scrape USING btree (created_at) WHERE (status =
  'failed'::nuq.job_status AND group_id IS NULL);

-- Plain group_id index for the cascading DELETE in nuq_group_crawl_clean.
-- The other partial (group_id, ...) indexes are all filtered by mode or status
-- so DELETE WHERE group_id IN (...) seq-scans the whole 18M-row table without
-- this. EXPLAIN confirmed ~7s/100 group_ids before adding this.
CREATE INDEX IF NOT EXISTS nuq_queue_scrape_group_id_idx ON nuq.queue_scrape (group_id) WHERE group_id IS NOT NULL;

-- Indexes for crawl-status.ts queries
-- For getGroupAnyJob: query by group_id, owner_id, and data->>'mode' = 'single_urls'
CREATE INDEX IF NOT EXISTS nuq_queue_scrape_group_owner_mode_idx ON nuq.queue_scrape (group_id, owner_id) WHERE ((data->>'mode') =
  'single_urls');

-- For getGroupNumericStats: query by group_id and data->>'mode', grouped by status
CREATE INDEX IF NOT EXISTS nuq_queue_scrape_group_mode_status_idx ON nuq.queue_scrape (group_id, status) WHERE ((data->>'mode') =
  'single_urls');

-- For getGroupJobs: query terminal jobs by group_id and data->>'mode' in listing order
CREATE INDEX IF NOT EXISTS nuq_queue_scrape_group_completed_listing_idx ON nuq.queue_scrape (group_id, finished_at ASC, created_at ASC)
  WHERE (status = 'completed'::nuq.job_status AND (data->>'mode') = 'single_urls');
CREATE INDEX IF NOT EXISTS nuq_queue_scrape_group_failed_listing_idx ON nuq.queue_scrape (group_id, id ASC) WHERE (status =
  'failed'::nuq.job_status AND (data->>'mode') = 'single_urls');

-- For group finish cron
CREATE INDEX IF NOT EXISTS idx_queue_scrape_group_status ON nuq.queue_scrape (group_id, status) WHERE status IN ('active', 'queued');

CREATE TABLE IF NOT EXISTS nuq.queue_scrape_backlog (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  data jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  priority int NOT NULL DEFAULT 0,
  listen_channel_id text, -- for listenable jobs over rabbitmq
  owner_id uuid,
  group_id uuid,
  times_out_at timestamptz,
  CONSTRAINT queue_scrape_backlog_pkey PRIMARY KEY (id)
);

-- For getBackloggedJobIDsOfOwner: query backlog by owner_id
CREATE INDEX IF NOT EXISTS nuq_queue_scrape_backlog_owner_id_idx ON nuq.queue_scrape_backlog (owner_id);

-- For getGroupNumericStats backlog query: query by group_id and data->>'mode' on backlog table
CREATE INDEX IF NOT EXISTS nuq_queue_scrape_backlog_group_mode_idx ON nuq.queue_scrape_backlog (group_id) WHERE ((data->>'mode') =
  'single_urls');

-- For nuq_queue_scrape_backlog_reaper: avoid seq scan over the entire backlog every minute
CREATE INDEX IF NOT EXISTS nuq_queue_scrape_backlog_times_out_at_idx ON nuq.queue_scrape_backlog (times_out_at);







CREATE TABLE IF NOT EXISTS nuq.queue_crawl_finished (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  status nuq.job_status NOT NULL DEFAULT 'queued'::nuq.job_status,
  data jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  priority int NOT NULL DEFAULT 0,
  lock uuid,
  locked_at timestamp with time zone,
  stalls integer,
  finished_at timestamp with time zone,
  listen_channel_id text, -- for listenable jobs over rabbitmq
  returnvalue jsonb, -- only for selfhost
  failedreason text, -- only for selfhost
  owner_id uuid,
  group_id uuid,
  CONSTRAINT queue_crawl_finished_pkey PRIMARY KEY (id)
);

ALTER TABLE nuq.queue_crawl_finished
SET (autovacuum_vacuum_scale_factor = 0.01,
    autovacuum_analyze_scale_factor = 0.01,
    autovacuum_vacuum_cost_limit = 10000,
    autovacuum_vacuum_cost_delay = 0);

CREATE INDEX IF NOT EXISTS queue_crawl_finished_active_locked_at_idx ON nuq.queue_crawl_finished USING btree (locked_at) WHERE (status =
  'active'::nuq.job_status);
CREATE INDEX IF NOT EXISTS nuq_queue_crawl_finished_queued_optimal_2_idx ON nuq.queue_crawl_finished (priority ASC, created_at ASC, id)
  WHERE (status = 'queued'::nuq.job_status);
CREATE INDEX IF NOT EXISTS nuq_queue_crawl_finished_failed_created_at_idx ON nuq.queue_crawl_finished USING btree (created_at) WHERE (status
  = 'failed'::nuq.job_status);
CREATE INDEX IF NOT EXISTS nuq_queue_crawl_finished_completed_created_at_idx ON nuq.queue_crawl_finished USING btree (created_at) WHERE
  (status = 'completed'::nuq.job_status);

-- Predicate-matching partial indexes for the standalone (group_id IS NULL)
-- cleaners; see note on queue_scrape above.
CREATE INDEX IF NOT EXISTS nuq_queue_crawl_finished_completed_standalone_created_at_idx ON nuq.queue_crawl_finished USING btree (created_at)
  WHERE (status = 'completed'::nuq.job_status AND group_id IS NULL);
CREATE INDEX IF NOT EXISTS nuq_queue_crawl_finished_failed_standalone_created_at_idx ON nuq.queue_crawl_finished USING btree (created_at)
  WHERE (status = 'failed'::nuq.job_status AND group_id IS NULL);

-- Plain group_id index for the cascading DELETE in nuq_group_crawl_clean.
-- See note on queue_scrape above.
CREATE INDEX IF NOT EXISTS nuq_queue_crawl_finished_group_id_idx ON nuq.queue_crawl_finished (group_id) WHERE group_id IS NOT NULL;




CREATE TABLE IF NOT EXISTS nuq.group_crawl (
  id uuid NOT NULL,
  status nuq.group_status NOT NULL DEFAULT 'active'::nuq.group_status,
  created_at timestamptz NOT NULL DEFAULT now(),
  owner_id uuid NOT NULL,
  ttl int8 NOT NULL DEFAULT 86400000,
  expires_at timestamptz,
  CONSTRAINT group_crawl_pkey PRIMARY KEY (id)
);

-- Index for group finish cron to find active groups
CREATE INDEX IF NOT EXISTS idx_group_crawl_status ON nuq.group_crawl (status) WHERE status = 'active'::nuq.group_status;

-- Index for nuq_group_crawl_clean victim selection. The status='active'
-- partial index above is the opposite predicate, so without this the cleaner
-- seq-scans the whole group_crawl table every 5 min.
CREATE INDEX IF NOT EXISTS nuq_group_crawl_completed_expires_at_idx ON nuq.group_crawl (expires_at) WHERE status =
  'completed'::nuq.group_status;

-- Index for backlog group_id lookups
CREATE INDEX IF NOT EXISTS idx_queue_scrape_backlog_group_id ON nuq.queue_scrape_backlog (group_id);
GRANT USAGE ON SCHEMA nuq TO app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA nuq TO app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA nuq TO app;
