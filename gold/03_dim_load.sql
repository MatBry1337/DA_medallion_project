-- Idempotent dim load: full refresh, deterministic surrogate keys via ROW_NUMBER().
TRUNCATE gold.fact_playback, gold.dim_user, gold.dim_content,
         gold.dim_device, gold.dim_date;

-- User dim: SCD2 history from Silver + surrogate key.
INSERT INTO gold.dim_user
    (user_sk, user_id, country, plan_code, monthly_price, valid_from, valid_to, is_current)
SELECT ROW_NUMBER() OVER (ORDER BY user_id, valid_from) AS user_sk,
       user_id, country, plan_code, monthly_price, valid_from, valid_to, is_current
FROM silver.dim_user_hist;

-- Content dim: SCD1, artist_name denormalised in.
INSERT INTO gold.dim_content
    (content_sk, content_id, title, content_type, artist_name,
     duration_seconds, release_date, is_explicit)
SELECT ROW_NUMBER() OVER (ORDER BY c.content_id) AS content_sk,
       c.content_id, c.title, c.content_type, a.artist_name,
       c.duration_seconds, c.release_date, c.is_explicit
FROM public.content c
LEFT JOIN public.artists a ON a.artist_id = c.artist_id;

-- Device dim: SCD1.
INSERT INTO gold.dim_device
    (device_sk, device_id, device_type, os_version)
SELECT ROW_NUMBER() OVER (ORDER BY device_id) AS device_sk,
       device_id, device_type, os_version
FROM public.devices;

-- Date dim: generated calendar.
INSERT INTO gold.dim_date
    (date_key, full_date, year, month, iso_week, weekday)
SELECT to_char(d, 'YYYYMMDD')::int        AS date_key,
       d::date                            AS full_date,
       EXTRACT(YEAR  FROM d)::int         AS year,
       EXTRACT(MONTH FROM d)::int         AS month,
       EXTRACT(WEEK  FROM d)::int         AS iso_week,
       trim(to_char(d, 'Day'))            AS weekday
FROM generate_series('2024-01-01'::date, '2024-04-30'::date, INTERVAL '1 day') AS d;
