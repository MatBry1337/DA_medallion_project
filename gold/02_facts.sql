 CREATE TABLE IF NOT EXISTS gold.fact_playback (
    event_id        BIGINT        NOT NULL,
    started_at      TIMESTAMPTZ   NOT NULL,
    user_sk         INTEGER       NOT NULL REFERENCES gold.dim_user(user_sk),
    content_sk      INTEGER       NOT NULL REFERENCES gold.dim_content(content_sk),
    device_sk       INTEGER                REFERENCES gold.dim_device(device_sk),
    date_key        INTEGER       NOT NULL REFERENCES gold.dim_date(date_key),
    minutes_played  NUMERIC(10,2) NOT NULL,
    play_count      INTEGER       NOT NULL,
    completed_plays INTEGER       NOT NULL,
    PRIMARY KEY (event_id, started_at)
) PARTITION BY RANGE (started_at);

-- One partition per month the data spans (started_at -> partition key).
 CREATE TABLE IF NOT EXISTS gold.fact_playback_2024_01 PARTITION OF gold.fact_playback
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
 CREATE TABLE IF NOT EXISTS gold.fact_playback_2024_02 PARTITION OF gold.fact_playback
    FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');
 CREATE TABLE IF NOT EXISTS gold.fact_playback_2024_03 PARTITION OF gold.fact_playback
    FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');
 CREATE TABLE IF NOT EXISTS gold.fact_playback_2024_04 PARTITION OF gold.fact_playback
    FOR VALUES FROM ('2024-04-01') TO ('2024-05-01');
