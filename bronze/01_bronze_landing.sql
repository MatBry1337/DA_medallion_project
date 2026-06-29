-- Create the medallion schemas (idempotent).
CREATE SCHEMA IF NOT EXISTS bronze;
CREATE SCHEMA IF NOT EXISTS silver;
CREATE SCHEMA IF NOT EXISTS gold;

-- Bronze landing: raw events, append-only, with provenance columns.
CREATE TABLE IF NOT EXISTS bronze.playback_events_raw (
    bronze_id      BIGSERIAL PRIMARY KEY,
    event_id       TEXT,
    user_id        TEXT,
    content_id     TEXT,
    device_id      TEXT,
    session_id     TEXT,
    started_at     TEXT,
    ms_played      TEXT,
    completed      TEXT,
    source         TEXT,
    source_system  TEXT,
    source_file    TEXT,
    raw_payload    JSONB,
    ingested_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO bronze.playback_events_raw
    (event_id, user_id, content_id, device_id, session_id,
     started_at, ms_played, completed, source,
     source_system, source_file, raw_payload, ingested_at)
SELECT
    e.event_id::text,
    e.user_id::text,
    e.content_id::text,
    e.device_id::text,
    e.session_id::text,
    e.started_at::text,
    e.ms_played::text,
    e.completed::text,
    e.source,
    'mobile_app',
    'plays_'  || to_char(e.started_at, 'YYYYMMDD') || '.jsonl',
    jsonb_build_object(
        'event_id',  e.event_id,
        'user_id',   e.user_id,
        'content_id',e.content_id,
        'started_at',e.started_at,
        'ms_played', e.ms_played
    ),
    e.started_at + INTERVAL '1 hour'   -- Simulate near-real-time arrival (keeps is_late meaningful)
FROM public.playback_events e
-- Load once: re-running appends nothing, and we never delete - Bronze stays append-only.
WHERE NOT EXISTS (SELECT 1 FROM bronze.playback_events_raw);
