UPDATE nuq.queue_scrape
SET status = 'queued'::nuq.job_status,
    lock = null,
    locked_at = null,
    stalls = COALESCE(stalls, 0) + 1
WHERE nuq.queue_scrape.locked_at <= now() - interval '1 minute'
  AND nuq.queue_scrape.status = 'active'::nuq.job_status
  AND COALESCE(nuq.queue_scrape.stalls, 0) < 9;

WITH stallfail AS (
  UPDATE nuq.queue_scrape
  SET status = 'failed'::nuq.job_status,
      lock = null,
      locked_at = null,
      stalls = COALESCE(stalls, 0) + 1
  WHERE nuq.queue_scrape.locked_at <= now() - interval '1 minute'
    AND nuq.queue_scrape.status = 'active'::nuq.job_status
    AND COALESCE(nuq.queue_scrape.stalls, 0) >= 9
  RETURNING id
)
SELECT pg_notify('nuq.queue_scrape', (id::text || '|' || 'failed'::text))
FROM stallfail;
