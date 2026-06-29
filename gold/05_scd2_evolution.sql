-- scd2 evolution demo (not a load): a plan change closes the old version, opens
-- a new one, and the fact re-attributes each play to the tier valid at play time.
--
-- mutates public.subscriptions; step 5 tears it down and rebuilds, so queries/
-- and tests/ run on clean data. run top to bottom.
-- at each "rebuild" marker run, in order: silver/03_dimensions.sql,
-- gold/03_dim_load.sql, gold/04_fact_load.sql.
--
-- this also covers the brief's "freshness key, not arrival": the load
-- full-refreshes dim_user_hist from subscriptions and re-derives validity with
-- LEAD(), so a stale arrival can never overwrite a fresher row.
--
-- subject: user 1 (premium_individual @9.99, open since 2023-07-01) -> family.
-- the seed lands every play on 2024-01-01 06:00-08:36, so we switch at 07:00 to
-- split user 1's plays (06:21/06:42 stay premium, 07:03..08:28 -> family).


-- step 1 - before. expect 2 rows: premium_individual @7.99 (closed), @9.99 (open).
SELECT 'before' AS phase, user_id, plan_code, monthly_price,
       valid_from, valid_to, is_current
FROM silver.dim_user_hist
WHERE user_id = 1 ORDER BY valid_from;


-- step 2 - the change: close the open period, open a new one.
UPDATE public.subscriptions
   SET ended_at = '2024-01-01 07:00:00+00',
       status   = 'expired'
 WHERE user_id = 1
   AND ended_at IS NULL;

INSERT INTO public.subscriptions (user_id, plan_id, started_at, ended_at, status)
VALUES (1, 4, '2024-01-01 07:00:00+00', NULL, 'active');


-- rebuild, then: step 3 - confirm in the dimension.
-- expect 3 rows: @9.99 now closed at 07:00, a new family row open from 07:00.
SELECT 'after change' AS phase, user_id, plan_code, monthly_price,
       valid_from, valid_to, is_current
FROM silver.dim_user_hist
WHERE user_id = 1 ORDER BY valid_from;


-- step 4 - the downstream effect on the fact. expect 2 rows for user 1:
-- premium_individual (early plays) and family (later plays), split at the switch.
SELECT du.plan_code,
       MIN(f.started_at)     AS first_play,
       MAX(f.started_at)     AS last_play,
       COUNT(*)              AS plays,
       SUM(f.minutes_played) AS minutes
FROM gold.fact_playback f
JOIN gold.dim_user du ON du.user_sk = f.user_sk
WHERE du.user_id = 1
GROUP BY du.plan_code
ORDER BY first_play;


-- step 5 - teardown: drop the family period, re-open the original @9.99.
DELETE FROM public.subscriptions
 WHERE user_id = 1 AND plan_id = 4 AND started_at = '2024-01-01 07:00:00+00';

UPDATE public.subscriptions
   SET ended_at = NULL,
       status   = 'active'
 WHERE user_id = 1 AND plan_id = 3;

-- rebuild again, then confirm we're back to the step 1 state (2 rows, no family).
SELECT 'after teardown' AS phase, user_id, plan_code, monthly_price,
       valid_from, valid_to, is_current
FROM silver.dim_user_hist
WHERE user_id = 1 ORDER BY valid_from;
