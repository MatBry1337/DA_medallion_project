-- ============================================================================
-- gold/05_scd2_evolution.sql  --  SCD2 EVOLUTION DEMONSTRATION (not a load)
-- ============================================================================
-- WHAT: proves an SCD2 plan change flows end-to-end -- the old version is
--   closed, a new one opened, and the fact RE-ATTRIBUTES each play to the tier
--   that was valid AT play time (point-in-time correctness).
--
-- PREREQUISITES: the full pipeline is already built and loaded
--   (bronze -> silver -> gold/01..04), so silver.dim_user_hist and the star
--   exist and are populated.
--
-- SIDE EFFECTS: this script MUTATES the source (public.subscriptions) to
--   simulate a real plan switch. STEP 5 is a TEARDOWN that restores the source
--   to its original state and rebuilds, so the rest of the pipeline
--   (queries/, tests/) runs on clean, unmodified data. Run this file
--   top-to-bottom; do not leave it half-run.
--
-- RUN ORDER (this DB has loads as .sql scripts, not procedures, so the rebuild
--   steps are explicit): for each "REBUILD" marker below, run, in order,
--   silver/03_dimensions.sql -> gold/03_dim_load.sql -> gold/04_fact_load.sql,
--   then continue with the next SELECT here.
--
-- DESIGN NOTE (covers the brief's "freshness key, not arrival" requirement):
--   the production load FULL-REFRESHES silver.dim_user_hist from the
--   authoritative public.subscriptions table, re-deriving validity with LEAD().
--   So close-old/open-new is IMPLICIT and idempotent -- a stale, out-of-order
--   arrival can never overwrite a fresher row, because validity always follows
--   the source's own started_at ordering, not arrival order.
--
-- DEMO SUBJECT: user 1 (currently plan_id 3, premium_individual @9.99, open
--   since 2023-07-01) upgrades to FAMILY (plan_id 4).
--
-- DATA NOTE: the seed clusters ALL 200 plays on 2024-01-01 06:00-08:36 UTC
--   (generator "g*47 % 7776000" never reaches the 90-day modulus). The switch
--   instant must land inside that morning to split a user's plays, so we use
--   2024-01-01 07:00 -- user 1's 06:21/06:42 plays stay premium_individual,
--   their 07:03..08:28 plays move to family.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- STEP 1 — BEFORE: user 1's SCD2 history as it stands.
--   Expected: 2 rows -- premium_individual @7.99 (closed), @9.99 (open).
-- ----------------------------------------------------------------------------
SELECT 'before' AS phase, user_id, plan_code, monthly_price,
       valid_from, valid_to, is_current
FROM silver.dim_user_hist
WHERE user_id = 1 ORDER BY valid_from;


-- ----------------------------------------------------------------------------
-- STEP 2 — CHANGE: inject the plan switch into the source. A real switch =
--   close the open period, then open a new one at the same instant.
-- ----------------------------------------------------------------------------
UPDATE public.subscriptions
   SET ended_at = '2024-01-01 07:00:00+00',
       status   = 'expired'
 WHERE user_id = 1
   AND ended_at IS NULL;                         -- the single open period

INSERT INTO public.subscriptions (user_id, plan_id, started_at, ended_at, status)
VALUES (1, 4, '2024-01-01 07:00:00+00', NULL, 'active');   -- new: family


-- ----------------------------------------------------------------------------
-- >>> REBUILD: run silver/03_dimensions.sql, gold/03_dim_load.sql,
--     gold/04_fact_load.sql (in that order), then run the SELECT below.
-- STEP 3 — CONFIRM the close/open landed in the dimension.
--   Expected: 3 rows -- the @9.99 row now CLOSED at 2024-01-01 07:00, and a
--   new FAMILY row OPEN from 2024-01-01 07:00.
-- ----------------------------------------------------------------------------
SELECT 'after change' AS phase, user_id, plan_code, monthly_price,
       valid_from, valid_to, is_current
FROM silver.dim_user_hist
WHERE user_id = 1 ORDER BY valid_from;


-- ----------------------------------------------------------------------------
-- STEP 4 — PROVE the downstream effect on the fact: user 1's plays are now
--   split across two tiers, each attributed to the tier valid at play time.
--   Expected: 2 rows -- premium_individual (06:21,06:42 plays) and
--   family (07:03..08:28 plays). One user, two tiers, split at the switch.
-- ----------------------------------------------------------------------------
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


-- ----------------------------------------------------------------------------
-- STEP 5 — TEARDOWN: restore the source to its original state so queries/ and
--   tests/ run on unmodified data. Removes the family period and re-opens the
--   original premium_individual @9.99 subscription.
-- ----------------------------------------------------------------------------
DELETE FROM public.subscriptions
 WHERE user_id = 1 AND plan_id = 4 AND started_at = '2024-01-01 07:00:00+00';

UPDATE public.subscriptions
   SET ended_at = NULL,
       status   = 'active'
 WHERE user_id = 1 AND plan_id = 3;              -- the original open period

-- >>> REBUILD AGAIN: run silver/03_dimensions.sql, gold/03_dim_load.sql,
--     gold/04_fact_load.sql, then run the SELECT below.
-- Expected: back to 2 rows -- identical to STEP 1. The demo left no trace.
SELECT 'after teardown' AS phase, user_id, plan_code, monthly_price,
       valid_from, valid_to, is_current
FROM silver.dim_user_hist
WHERE user_id = 1 ORDER BY valid_from;
