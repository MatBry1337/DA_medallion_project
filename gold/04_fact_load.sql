INSERT INTO gold.fact_playback
    (event_id, started_at, user_sk, content_sk, device_sk, date_key,
     minutes_played, play_count, completed_plays)
SELECT
    s.event_id,
    s.started_at,
    du.user_sk,
    dc.content_sk,
    dd.device_sk,
    dt.date_key,
    ROUND(s.ms_played / 60000.0, 2)         AS minutes_played,
    1                                       AS play_count,
    CASE WHEN s.completed THEN 1 ELSE 0 END AS completed_plays
FROM silver.playback_events s

JOIN gold.dim_user du
      ON du.user_id = s.user_id
     AND s.started_at >= du.valid_from
     AND (du.valid_to IS NULL OR s.started_at < du.valid_to)

JOIN gold.dim_content dc ON dc.content_id = s.content_id
LEFT JOIN gold.dim_device dd ON dd.device_id = s.device_id

JOIN gold.dim_date dt ON dt.date_key = to_char(s.started_at, 'YYYYMMDD')::int

ON CONFLICT (event_id, started_at) DO NOTHING;

-- RECONCILE: check if every clean silver event land once

SELECT
    (SELECT COUNT(*) FROM silver.playback_events) AS silver_rows,
    (SELECT COUNT(*) FROM gold.fact_playback)     AS gold_rows;
