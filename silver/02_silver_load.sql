MERGE INTO silver.playback_events AS s
  USING (
      SELECT
          event_id::bigint                       AS event_id,
          user_id::int                           AS user_id,
          content_id::int                        AS content_id,
          NULLIF(device_id, '')::int             AS device_id,
          session_id::uuid                       AS session_id,
          started_at::timestamptz                AS started_at,
          ms_played::int                         AS ms_played,
          (completed = 'true')                   AS completed,
          source,
          (ingested_at - started_at::timestamptz > INTERVAL '24 hours')      AS is_late,
          ingested_at,
          ROW_NUMBER() OVER (
              PARTITION BY event_id::bigint
              ORDER BY ingested_at DESC
          ) AS rn
      FROM bronze.playback_events_raw
      WHERE event_id ~ '^[0-9]+$'         -- need to be all digits
          AND session_id IS NOT NULL AND session_id <> ''    -- session id is present
          AND ms_played ~ '^[0-9]+$'           -- need to be all digits
  ) b ON s.event_id = b.event_id

  WHEN NOT MATCHED AND b.rn = 1 THEN
      INSERT (event_id, user_id, content_id, device_id, session_id,
              started_at, ms_played, completed, source, is_late, ingested_at)
      VALUES (b.event_id, b.user_id, b.content_id, b.device_id, b.session_id,
              b.started_at, b.ms_played, b.completed, b.source, b.is_late, b.ingested_at);