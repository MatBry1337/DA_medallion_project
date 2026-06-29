-- Churn risk: currently-paying users whose weekly listening keeps falling (LAG + HAVING).
-- The seed has all plays on one day, so there's no weekly trend. To show it, inject
-- 4 falling-minute plays for user 29 (paying, no plays), run, then tear down.
-- Mutates bronze/silver/fact; step 3 restores. Run top to bottom.

-- Step 1 - Inject a declining 4-week series for user 29 (10 -> 6 -> 3 -> 1 min).
INSERT INTO bronze.playback_events_raw
    (event_id, user_id, content_id, device_id, session_id, started_at,
     ms_played, completed, source, source_system, source_file, raw_payload,
     ingested_at)
VALUES
    ('999101','29','1','1', gen_random_uuid()::text, '2024-01-01 08:00:00+00',
     '600000','true','queue','mobile_app','plays_churn.jsonl', NULL,
     '2024-01-01 09:00:00+00'),
    ('999102','29','1','1', gen_random_uuid()::text, '2024-01-08 08:00:00+00',
     '360000','true','queue','mobile_app','plays_churn.jsonl', NULL,
     '2024-01-08 09:00:00+00'),
    ('999103','29','1','1', gen_random_uuid()::text, '2024-01-15 08:00:00+00',
     '180000','true','queue','mobile_app','plays_churn.jsonl', NULL,
     '2024-01-15 09:00:00+00'),
    ('999104','29','1','1', gen_random_uuid()::text, '2024-01-22 08:00:00+00',
     '60000','true','queue','mobile_app','plays_churn.jsonl', NULL,
     '2024-01-22 09:00:00+00');

-- Rebuild: silver/02_silver_load.sql, then gold/04_fact_load.sql.

-- Step 2 - The detector. Expect user 29 flagged (3 declines / 3 comparisons).
WITH paying AS (
    SELECT user_id
    FROM gold.dim_user
    WHERE is_current AND plan_code <> 'free'
),
weekly AS (
    SELECT du.user_id,
           date_trunc('week', f.started_at) AS week,
           SUM(f.minutes_played) AS minutes
    FROM gold.fact_playback f
    JOIN gold.dim_user du ON du.user_sk = f.user_sk
    WHERE du.user_id IN (SELECT user_id FROM paying)
    GROUP BY du.user_id, week
),
trend AS (
    SELECT user_id, week, minutes,
           LAG(minutes) OVER (PARTITION BY user_id ORDER BY week) AS prev_minutes
    FROM weekly
)
SELECT
    user_id,
    COUNT(*) FILTER (WHERE prev_minutes IS NOT NULL)                            AS weeks_compared,
    COUNT(*) FILTER (WHERE prev_minutes IS NOT NULL AND minutes < prev_minutes) AS weeks_declined
FROM trend
GROUP BY user_id
HAVING COUNT(*) FILTER (WHERE prev_minutes IS NOT NULL) >= 2
   AND COUNT(*) FILTER (WHERE prev_minutes IS NOT NULL AND minutes < prev_minutes)
     = COUNT(*) FILTER (WHERE prev_minutes IS NOT NULL);

-- Step 3 - Teardown: remove the injected plays, back to baseline.
DELETE FROM gold.fact_playback         WHERE event_id IN (999101,999102,999103,999104);
DELETE FROM silver.playback_events     WHERE event_id IN (999101,999102,999103,999104);
DELETE FROM bronze.playback_events_raw WHERE event_id IN ('999101','999102','999103','999104');
