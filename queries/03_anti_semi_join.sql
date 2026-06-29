-- Paying users (current tier <> 'free') with no plays in the 30 days before the
-- latest event. Anchored to MAX(started_at), not NOW() because data is from 2024.
WITH last_event AS (
    SELECT MAX(started_at) AS max_ts FROM gold.fact_playback
),
paying_users AS (
    SELECT user_id, plan_code
    FROM gold.dim_user
    WHERE is_current AND plan_code <> 'free'
)
SELECT p.user_id, p.plan_code
FROM paying_users p
WHERE NOT EXISTS (
    SELECT 1
    FROM gold.fact_playback f
    JOIN gold.dim_user du ON du.user_sk = f.user_sk
    CROSS JOIN last_event le
    WHERE du.user_id = p.user_id
      AND f.started_at >= le.max_ts - INTERVAL '30 days'
)
ORDER BY p.user_id;
