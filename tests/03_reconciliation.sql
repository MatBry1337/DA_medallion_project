-- Reconciliation: silver source rows vs fact rows. They should match.

-- Counts side by side, with the difference.
SELECT
    (SELECT COUNT(*) FROM silver.playback_events) AS silver_rows,
    (SELECT COUNT(*) FROM gold.fact_playback)     AS fact_rows,
    (SELECT COUNT(*) FROM silver.playback_events)
      - (SELECT COUNT(*) FROM gold.fact_playback) AS difference;

-- Explains any gap: Silver events missing from the fact (no covering dim version).
-- Returns 0 rows when nothing is missing.
SELECT s.event_id, s.user_id, s.started_at
FROM silver.playback_events s
LEFT JOIN gold.fact_playback f ON f.event_id = s.event_id
WHERE f.event_id IS NULL;
