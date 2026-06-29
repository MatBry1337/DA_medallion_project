-- SCD2 evolution demo (not a load): a plan change closes the old version, opens
-- a new one, and the fact re-attributes each play to the tier valid at play time.
-- Mutates public.subscriptions; step 5 tears it down. Run top to bottom.
-- At each "rebuild" marker run: silver/03_dimensions.sql, gold/03_dim_load.sql,
-- gold/04_fact_load.sql.
--
-- Subject: user 1 (premium_individual @9.99, open since 2023-07-01) -> family.
-- All plays land on 2024-01-01 06:00-08:36, so we switch at 07:00 to split user
-- 1's plays (06:21/06:42 stay premium, 07:03..08:28 -> family).

-- Step 1 - Before. Expect 2 rows: premium_individual @7.99 (closed), @9.99 (open).
SELECT 'before' AS phase, user_id, plan_code, monthly_price,
       valid_from, valid_to, is_current
FROM silver.dim_user_hist
WHERE user_id = 1 ORDER BY valid_from;


-- Step 2 - The change: close the open period, open a new one.
UPDATE public.subscriptions
   SET ended_at = '2024-01-01 07:00:00+00',
       status   = 'expired'
 WHERE user_id = 1
   AND ended_at IS NULL;

INSERT INTO public.subscriptions (user_id, plan_id, started_at, ended_at, status)
VALUES (1, 4, '2024-01-01 07:00:00+00', NULL, 'active');


-- Rebuild, then: Step 3 - Confirm in the dimension.
-- Expect 3 rows: @9.99 now closed at 07:00, a new family row open from 07:00.
SELECT 'after change' AS phase, user_id, plan_code, monthly_price,
       valid_from, valid_to, is_current
FROM silver.dim_user_hist
WHERE user_id = 1 ORDER BY valid_from;


-- Step 4 - The downstream effect on the fact. Expect 2 rows for user 1:
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


-- Step 5 - Teardown: drop the family period, re-open the original @9.99.
DELETE FROM public.subscriptions
 WHERE user_id = 1 AND plan_id = 4 AND started_at = '2024-01-01 07:00:00+00';

UPDATE public.subscriptions
   SET ended_at = NULL,
       status   = 'active'
 WHERE user_id = 1 AND plan_id = 3;

-- Rebuild again, then confirm we're back to the step 1 state (2 rows, no family).
SELECT 'after teardown' AS phase, user_id, plan_code, monthly_price,
       valid_from, valid_to, is_current
FROM silver.dim_user_hist
WHERE user_id = 1 ORDER BY valid_from;
