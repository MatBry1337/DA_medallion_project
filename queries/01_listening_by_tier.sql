-- Minutes per plan tier, each play counted under the tier active at play time
-- (point-in-time is already baked into f.user_sk). Pct + rank are window functions.
SELECT
    du.plan_code,
    d.year,
    d.month,
    SUM(f.minutes_played)                                    AS minutes,
    SUM(f.play_count)                                        AS plays,
    ROUND(100.0 * SUM(f.minutes_played)
                / SUM(SUM(f.minutes_played)) OVER (), 1)     AS pct_of_total,
    RANK() OVER (ORDER BY SUM(f.minutes_played) DESC)        AS tier_rank
FROM gold.fact_playback f
JOIN gold.dim_user du ON du.user_sk = f.user_sk
JOIN gold.dim_date d  ON d.date_key = f.date_key
GROUP BY du.plan_code, d.year, d.month
ORDER BY minutes DESC;
