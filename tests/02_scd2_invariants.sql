-- Scd2 invariants on silver.dim_user_hist. Each select returns 0 rows when clean.

-- 1. Exactly one current version per user.
SELECT user_id, COUNT(*) FILTER (WHERE is_current) AS current_rows
FROM silver.dim_user_hist
GROUP BY user_id
HAVING COUNT(*) FILTER (WHERE is_current) <> 1;

-- 2. No overlapping intervals: an earlier version must end before a later one
SELECT a.user_id, a.valid_from AS a_from, b.valid_from AS b_from
FROM silver.dim_user_hist a
JOIN silver.dim_user_hist b
  ON b.user_id = a.user_id
 AND b.valid_from > a.valid_from
WHERE a.valid_to IS NULL OR a.valid_to > b.valid_from;

-- 3. No gaps: every fact event is covered by the dim version it points to
SELECT f.event_id, f.started_at
FROM gold.fact_playback f
JOIN gold.dim_user du ON du.user_sk = f.user_sk
WHERE f.started_at < du.valid_from
   OR (du.valid_to IS NOT NULL AND f.started_at >= du.valid_to);
