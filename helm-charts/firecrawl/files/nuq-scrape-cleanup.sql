DELETE FROM nuq.queue_scrape
WHERE nuq.queue_scrape.status = 'completed'::nuq.job_status
  AND nuq.queue_scrape.created_at < now() - interval '1 hour'
  AND group_id IS NULL;

DELETE FROM nuq.queue_scrape
WHERE nuq.queue_scrape.status = 'failed'::nuq.job_status
  AND nuq.queue_scrape.created_at < now() - interval '6 hours'
  AND group_id IS NULL;
