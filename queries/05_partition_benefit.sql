-- partition pruning: filtering on the partition key (started_at) makes the
-- planner read only the relevant monthly partition. There is no indexes in this project!
-- all seed data is in 2024-01, so January reads only fact_playback_2024_01;
-- the other months are pruned. Can drop WHERE and then all data is scanned.

EXPLAIN (ANALYZE, COSTS OFF, BUFFERS)
SELECT du.plan_code, SUM(f.minutes_played) AS minutes
FROM gold.fact_playback f
JOIN gold.dim_user du ON du.user_sk = f.user_sk
WHERE f.started_at >= '2024-01-01' AND f.started_at < '2024-02-01'
GROUP BY du.plan_code;

-- WITH WHERE FOR ONE MONTH

--HashAggregate (actual time=0.155..0.157 rows=5 loops=1)
--  Group Key: du.plan_code
--  Batches: 1  Memory Usage: 24kB
--  Buffers: shared hit=3
--  ->  Hash Join (actual time=0.036..0.098 rows=200 loops=1)
--        Hash Cond: (f.user_sk = du.user_sk)
--        Buffers: shared hit=3
--        ->  Seq Scan on fact_playback_2024_01 f (actual time=0.008..0.038 rows=200 loops=1)
--              Filter: ((started_at >= '2024-01-01 00:00:00+01'::timestamp with time zone) AND (started_at < '2024-02-01 00:00:00+01'::timestamp with time zone))
--              Buffers: shared hit=2
--        ->  Hash (actual time=0.020..0.020 rows=39 loops=1)
--              Buckets: 1024  Batches: 1  Memory Usage: 10kB
--              Buffers: shared hit=1
--              ->  Seq Scan on dim_user du (actual time=0.003..0.008 rows=39 loops=1)
--                    Buffers: shared hit=1
--Planning:
--  Buffers: shared hit=3 dirtied=1
--Planning Time: 0.267 ms
--Execution Time: 0.199 ms

-- WITHOUT WHERE FOR ONE MONTH

--HashAggregate (actual time=0.095..0.097 rows=5 loops=1)
--  Group Key: du.plan_code
--  Batches: 1  Memory Usage: 24kB
--  Buffers: shared hit=3
--  ->  Hash Join (actual time=0.027..0.066 rows=200 loops=1)
--        Hash Cond: (f.user_sk = du.user_sk)
--        Buffers: shared hit=3
--        ->  Append (actual time=0.009..0.031 rows=200 loops=1)
--              Buffers: shared hit=2
--              ->  Seq Scan on fact_playback_2024_01 f_1 (actual time=0.008..0.020 rows=200 loops=1)
--                    Buffers: shared hit=2
--              ->  Seq Scan on fact_playback_2024_02 f_2 (actual time=0.001..0.001 rows=0 loops=1)
--              ->  Seq Scan on fact_playback_2024_03 f_3 (actual time=0.000..0.000 rows=0 loops=1)
--              ->  Seq Scan on fact_playback_2024_04 f_4 (actual time=0.000..0.000 rows=0 loops=1)
--        ->  Hash (actual time=0.012..0.012 rows=39 loops=1)
--              Buckets: 1024  Batches: 1  Memory Usage: 10kB
--              Buffers: shared hit=1
--              ->  Seq Scan on dim_user du (actual time=0.003..0.005 rows=39 loops=1)
--                    Buffers: shared hit=1
--Planning:
--  Buffers: shared hit=3
--Planning Time: 0.175 ms
--Execution Time: 0.130 ms