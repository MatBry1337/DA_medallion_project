-- Each query should return 0 to prove that data is clean

-- 1. Grain uniqueness: no duplicate (event_id, started_at) in the fact.
SELECT event_id, started_at, COUNT(*)
FROM gold.fact_playback
GROUP BY event_id, started_at
HAVING COUNT(*) > 1;

-- 2. FK integrity: no fact row pointing at a missing dimension key.
SELECT f.event_id
FROM gold.fact_playback f
LEFT JOIN gold.dim_user    du ON du.user_sk    = f.user_sk
LEFT JOIN gold.dim_content dc ON dc.content_sk = f.content_sk
LEFT JOIN gold.dim_date    d  ON d.date_key    = f.date_key
WHERE du.user_sk IS NULL OR dc.content_sk IS NULL OR d.date_key IS NULL;

-- 3. Value range: minutes and counts are never negative.
SELECT event_id
FROM gold.fact_playback
WHERE minutes_played < 0 OR play_count < 0 OR completed_plays < 0;

-- 4. Completeness: the fact is current with its silver source. Compare against
--    the source's max started_at (not NOW() - the data is historical).
SELECT
    s.max_ts AS silver_max,
    f.max_ts AS fact_max
FROM (SELECT MAX(started_at) AS max_ts FROM silver.playback_events) s,
     (SELECT MAX(started_at) AS max_ts FROM gold.fact_playback)     f
WHERE s.max_ts <> f.max_ts;

-- 5. Null checks on required fact columns.
SELECT event_id
FROM gold.fact_playback
WHERE user_sk IS NULL OR content_sk IS NULL OR date_key IS NULL
   OR started_at IS NULL OR minutes_played IS NULL;
