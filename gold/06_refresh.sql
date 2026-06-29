-- windowed refresh: rebuild the fact for one time window (delete-then-insert)
-- and show it absorbs a late-arriving event into an already-built day. only the
-- changed day is recomputed; re-running the same window is a no-op (idempotent).
--
-- plain delete + insert with the window hardcoded to the demo day (2024-01-01);
-- a parameterized function would avoid repeating the block - see docs/05.
-- the demo injects one late event into bronze + silver; step 5 tears it down.


-- step 1 - before. expect 200 plays on 2024-01-01.
SELECT 'before' AS phase, COUNT(*) AS plays_on_jan01
FROM gold.fact_playback
WHERE started_at >= '2024-01-01' AND started_at < '2024-01-02';


-- step 2 - a late event: happened 06:30, arrived ~30h later (> 24h -> is_late).
INSERT INTO bronze.playback_events_raw
    (event_id, user_id, content_id, device_id, session_id, started_at,
     ms_played, completed, source, source_system, source_file, raw_payload,
     ingested_at)
VALUES
    ('999001', '1', '1', '1', gen_random_uuid()::text,
     '2024-01-01 06:30:00+00', '180000', 'true', 'queue',
     'mobile_app', 'plays_late.jsonl', NULL,
     '2024-01-01 06:30:00+00'::timestamptz + INTERVAL '30 hours');

-- re-run silver/02_silver_load.sql, then: step 3 - expect is_late = true.
SELECT event_id, started_at, ingested_at, is_late
FROM silver.playback_events WHERE event_id = 999001;


-- step 4 - refresh the day. delete the window first so re-running can't dup.
-- expect 201 after; re-run the delete+insert and it stays 201.
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

SELECT 'after refresh' AS phase, COUNT(*) AS plays_on_jan01
FROM gold.fact_playback
WHERE started_at >= '2024-01-01' AND started_at < '2024-01-02';


-- step 5 - teardown: drop the late event, refresh the day back to 200.
DELETE FROM silver.playback_events     WHERE event_id = 999001;
DELETE FROM bronze.playback_events_raw WHERE event_id = '999001';

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

SELECT 'after teardown' AS phase, COUNT(*) AS plays_on_jan01   -- expect 200
FROM gold.fact_playback
WHERE started_at >= '2024-01-01' AND started_at < '2024-01-02';
