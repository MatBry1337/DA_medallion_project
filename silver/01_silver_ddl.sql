CREATE TABLE silver.playback_events (
    event_id     BIGINT PRIMARY KEY,
    user_id      INTEGER NOT NULL,
    content_id   INTEGER NOT NULL,
    device_id    INTEGER,
    session_id   UUID NOT NULL,
    started_at   TIMESTAMPTZ NOT NULL,
    ms_played    INTEGER NOT NULL CHECK (ms_played >= 0),
    completed    BOOLEAN NOT NULL,
    source       VARCHAR(20) NOT NULL,
    is_late      BOOLEAN NOT NULL DEFAULT FALSE, -- arrived > 24h after event time
    ingested_at  TIMESTAMPTZ NOT NULL,
    silver_loaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);