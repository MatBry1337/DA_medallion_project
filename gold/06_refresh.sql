-- ============================================================================
-- gold/06_refresh.sql  --  WINDOWED IDEMPOTENT REFRESH + late-data absorption
-- ============================================================================
-- WHAT: rebuild the fact for ONE explicit time window (DELETE-then-INSERT),
--   and demonstrate that it absorbs a LATE-ARRIVING event into an already-built
--   day without touching any other day.
--
-- WHY WINDOWED (not a full reload): only the changed day is recomputed. The
--   DELETE/INSERT are scoped to [from, to); partition pruning touches only the
--   affected month. Re-running the SAME window leaves the result unchanged
--   -> idempotent.
--
-- NOTE: this is plain DELETE + INSERT with the window HARDCODED to the demo day
--   (2024-01-01). To refresh another window you copy the block and change the
--   two dates. (A parameterized function would avoid that repetition -- see
--   docs/05_trade_offs.md.)
--
-- PREREQUISITES: pipeline built and loaded (bronze -> silver -> gold/01..04).
-- SIDE EFFECTS: the demo injects one late event into bronze + silver; STEP 5
--   tears it down and refreshes the day back to its original state.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- STEP 1 — BEFORE: plays in the built day 2024-01-01.  Expected: 200.
-- ----------------------------------------------------------------------------
SELECT 'before' AS phase, COUNT(*) AS plays_on_jan01
FROM gold.fact_playback
WHERE started_at >= '2024-01-01' AND started_at < '2024-01-02';


-- ----------------------------------------------------------------------------
-- STEP 2 — A late event: it HAPPENED 2024-01-01 06:30 but only reached us ~30h
--   later (> 24h => Silver will flag is_late). Land it in Bronze (append-only).
-- ----------------------------------------------------------------------------
INSERT INTO bronze.playback_events_raw
    (event_id, user_id, content_id, device_id, session_id, started_at,
     ms_played, completed, source, source_system, source_file, raw_payload,
     ingested_at)
VALUES
    ('999001', '1', '1', '1', gen_random_uuid()::text,
     '2024-01-01 06:30:00+00', '180000', 'true', 'queue',
     'mobile_app', 'plays_late.jsonl', NULL,
     '2024-01-01 06:30:00+00'::timestamptz + INTERVAL '30 hours');

-- ----------------------------------------------------------------------------
-- >>> Re-run silver/02_silver_load.sql (the MERGE picks up the new event).
-- STEP 3 — Confirm Silver typed it and flagged it late.  Expected: is_late = TRUE.
-- ----------------------------------------------------------------------------
SELECT event_id, started_at, ingested_at, is_late
FROM silver.playback_events WHERE event_id = 999001;

-- ----------------------------------------------------------------------------
-- STEP 4 — REFRESH the day (DELETE-then-INSERT for [2024-01-01, 2024-01-02)).
--   The late event is absorbed into the already-built day.  Expected after: 201.
-- ----------------------------------------------------------------------------
-- (1) clear the window so re-running can't duplicate rows
DELETE FROM gold.fact_playback
 WHERE started_at >= '2024-01-01' AND started_at < '2024-01-02';

-- (2) re-derive the window from Silver, point-in-time as always
INSERT INTO gold.fact_playback
    (event_id, started_at, user_sk, content_sk, device_sk, date_key,
     minutes_played, play_count, completed_plays)
SELECT s.event_id, s.started_at, du.user_sk, dc.content_sk, dd.device_sk,
       to_char(s.started_at, 'YYYYMMDD')::int,
       ROUND(s.ms_played / 60000.0, 2), 1,
       CASE WHEN s.completed THEN 1 ELSE 0 END
FROM silver.playback_events s
JOIN gold.dim_user du
      ON du.user_id = s.user_id
     AND s.started_at >= du.valid_from
     AND (du.valid_to IS NULL OR s.started_at < du.valid_to)
JOIN gold.dim_content dc ON dc.content_id = s.content_id
LEFT JOIN gold.dim_device dd ON dd.device_id = s.device_id
JOIN gold.dim_date dt ON dt.date_key = to_char(s.started_at, 'YYYYMMDD')::int
WHERE s.started_at >= '2024-01-01' AND s.started_at < '2024-01-02';

SELECT 'after refresh' AS phase, COUNT(*) AS plays_on_jan01
FROM gold.fact_playback
WHERE started_at >= '2024-01-01' AND started_at < '2024-01-02';

-- IDEMPOTENCY: re-run the same two statements (the DELETE + INSERT in STEP 4)
-- and count again -> still 201. The DELETE makes the window safe to rebuild.


-- ----------------------------------------------------------------------------
-- STEP 5 — TEARDOWN: remove the late event everywhere and refresh the day back
--   to 200, so queries/ and tests/ run on clean data.
-- ----------------------------------------------------------------------------
DELETE FROM silver.playback_events     WHERE event_id = 999001;
DELETE FROM bronze.playback_events_raw WHERE event_id = '999001';

-- refresh the day once more (same DELETE-then-INSERT, now without the late row)
DELETE FROM gold.fact_playback
 WHERE started_at >= '2024-01-01' AND started_at < '2024-01-02';

INSERT INTO gold.fact_playback
    (event_id, started_at, user_sk, content_sk, device_sk, date_key,
     minutes_played, play_count, completed_plays)
SELECT s.event_id, s.started_at, du.user_sk, dc.content_sk, dd.device_sk,
       to_char(s.started_at, 'YYYYMMDD')::int,
       ROUND(s.ms_played / 60000.0, 2), 1,
       CASE WHEN s.completed THEN 1 ELSE 0 END
FROM silver.playback_events s
JOIN gold.dim_user du
      ON du.user_id = s.user_id
     AND s.started_at >= du.valid_from
     AND (du.valid_to IS NULL OR s.started_at < du.valid_to)
JOIN gold.dim_content dc ON dc.content_id = s.content_id
LEFT JOIN gold.dim_device dd ON dd.device_id = s.device_id
JOIN gold.dim_date dt ON dt.date_key = to_char(s.started_at, 'YYYYMMDD')::int
WHERE s.started_at >= '2024-01-01' AND s.started_at < '2024-01-02';

SELECT 'after teardown' AS phase, COUNT(*) AS plays_on_jan01
FROM gold.fact_playback
WHERE started_at >= '2024-01-01' AND started_at < '2024-01-02';   -- Expected: 200
