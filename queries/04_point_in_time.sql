-- Minutes per tier two ways: point-in-time (tier at play time, via f.user_sk)
-- vs naive (user's current tier), to show the SCD2 history changes the answer.
-- On the clean seed they're identical, so we re-use the gold/05 change: user 1
-- switches premium_individual -> family at 2024-01-01 07:00, splitting their plays.
-- Mutates public.subscriptions; step 3 tears it down. Run top to bottom.

-- Step 1 - Apply the change (user 1 -> family @ 2024-01-01 07:00).
UPDATE public.subscriptions
   SET ended_at = '2024-01-01 07:00:00+00', status = 'expired'
 WHERE user_id = 1 AND ended_at IS NULL;

INSERT INTO public.subscriptions (user_id, plan_id, started_at, ended_at, status)
VALUES (1, 4, '2024-01-01 07:00:00+00', NULL, 'active');

-- Rebuild: silver/03_dimensions.sql, gold/03_dim_load.sql, gold/04_fact_load.sql.

-- Step 2 - The contrast. Expect premium_individual and family to differ.
WITH point_in_time AS (
    SELECT du.plan_code, SUM(f.minutes_played) AS minutes
    FROM gold.fact_playback f
    JOIN gold.dim_user du ON du.user_sk = f.user_sk
    GROUP BY du.plan_code
),
naive_current AS (
    SELECT cur.plan_code, SUM(f.minutes_played) AS minutes
    FROM gold.fact_playback f
    JOIN gold.dim_user pit ON pit.user_sk = f.user_sk
    JOIN gold.dim_user cur ON cur.user_id = pit.user_id
                          AND cur.is_current
    GROUP BY cur.plan_code
)
SELECT
    COALESCE(p.plan_code, n.plan_code)              AS plan_code,
    p.minutes                                       AS minutes_point_in_time,
    n.minutes                                       AS minutes_naive_current,
    COALESCE(p.minutes, 0) - COALESCE(n.minutes, 0) AS difference
FROM point_in_time p
FULL OUTER JOIN naive_current n ON n.plan_code = p.plan_code
ORDER BY plan_code;

-- Step 3 - Teardown, then rebuild so the rest runs on clean data.
DELETE FROM public.subscriptions
 WHERE user_id = 1 AND plan_id = 4 AND started_at = '2024-01-01 07:00:00+00';
UPDATE public.subscriptions
   SET ended_at = NULL, status = 'active'
 WHERE user_id = 1 AND plan_id = 3;


-- Rebuild: silver/03_dimensions.sql, gold/03_dim_load.sql, gold/04_fact_load.sql
