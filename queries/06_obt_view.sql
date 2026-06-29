-- one big table: one flat row per play with all the descriptive attributes
-- (user + tier at play time, content, device, date). View over the star so it
-- always reflects the current fact
CREATE OR REPLACE VIEW gold.obt_playback AS
SELECT
    f.event_id,
    f.started_at,
    du.user_id,
    du.plan_code,
    du.monthly_price,
    du.country,
    dc.title,
    dc.artist_name,
    dc.content_type,
    dc.is_explicit,
    dd.device_type,
    dd.os_version,
    d.full_date,
    d.year,
    d.month,
    d.iso_week,
    d.weekday,
    f.minutes_played,
    f.play_count,
    f.completed_plays
FROM gold.fact_playback f
JOIN      gold.dim_user    du ON du.user_sk    = f.user_sk
JOIN      gold.dim_content dc ON dc.content_sk = f.content_sk
LEFT JOIN gold.dim_device  dd ON dd.device_sk  = f.device_sk
JOIN      gold.dim_date    d  ON d.date_key    = f.date_key;

SELECT * FROM gold.obt_playback ORDER BY started_at LIMIT 20;
