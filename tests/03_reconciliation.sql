-- Reconciliation: silver source rows vs fact rows. They should match.

-- Counts side by side (and the difference).
SELECT
    (SELECT COUNT(*) FROM silver.playback_events) AS silver_rows,
    (SELECT COUNT(*) FROM gold.fact_playback)     AS fact_rows,
    (SELECT COUNT(*) FROM silver.playback_events)
      - (SELECT COUNT(*) FROM gold.fact_playback) AS difference;

-- The explanation: silver events that never made it into the fact, for example an
-- event with no dim_user version covering its play time. Returns 0 rows when
-- nothing is missing, otherwise these rows ARE the difference above.
SELECT s.event_id, s.user_id, s.started_at
FROM silver.playback_events s
LEFT JOIN gold.fact_playback f ON f.event_id = s.event_id
WHERE f.event_id IS NULL;
