-- running total of minutes per user (in play order) + delta vs the previous play.

WITH user_plays AS (
    SELECT du.user_id, f.started_at, f.minutes_played
    FROM gold.fact_playback f
    JOIN gold.dim_user du ON du.user_sk = f.user_sk
)
SELECT
    user_id,
    started_at,
    minutes_played,
    SUM(minutes_played) OVER (
        PARTITION BY user_id ORDER BY started_at
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    )                                                       AS cumulative_minutes,
    minutes_played - LAG(minutes_played) OVER (
        PARTITION BY user_id ORDER BY started_at
    )                                                       AS delta_vs_prev_play
FROM user_plays
ORDER BY user_id, started_at;
