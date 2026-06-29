# Trade-offs

A few design choices I had to make, the other options I looked at, and why I
went the way I did.

## 1. Partitioning the fact by `started_at`, by month

I split `fact_playback` into monthly partitions on `started_at` (event time).

I thought about partitioning on ingestion time instead, but that's not how the
data gets queried. People ask things like "how much listening in March", so they
filter on when the play happened. If the partition column doesn't match what the
queries filter on, pruning never happens and the partitions are pointless.

Daily partitions felt like overkill for this amount of data, and they'd just add
planner overhead. Monthly lines up with the per-month, per-tier questions.

No partitioning at all (and leaning on indexes) wasn't an option here, and it
isn't really the analytics way anyway. You make big scans fast with the model
and partitioning, not with B-tree indexes on a warehouse fact.

The catch: I have to create partitions before the data lands (I made Jan–Apr
2024 up front), and an event outside every partition's range would fail to load.

## 2. Refreshing with a windowed DELETE then INSERT

To refresh the fact I delete a time window and re-insert it from Silver
(`gold/06`).

I could have done an incremental MERGE/upsert into the fact, but that's more
machinery than I need. Deleting and re-inserting a window is simple, it's
idempotent on its own (running the same window twice gives the same result), and
it plays nicely with the partitions because it only touches the days that
changed.

Reloading the whole table every time was the other option. It works now but
wouldn't scale, and the window lets me refresh just the day a late event landed
in instead of everything.

The catch: in the plain-SQL version the window is hardcoded and the DELETE+INSERT
block gets repeated. A small function with parameters would remove that
repetition. I kept it as plain SQL because it's easier to read and follow.

## 3. A star with denormalization, not a snowflake

I put `artist_name` straight into `dim_content` instead of giving artists their
own dimension.

The snowflake version (a separate `dim_artist` that `dim_content` points to)
would mean an extra join on every query that wants the artist name. A star keeps
each dimension flat, so a query only touches the fact plus one dimension.

The catch: the artist name is repeated across a lot of `dim_content` rows, and
renaming an artist means reloading. I'm fine with that. `dim_content` is SCD1 so
it gets overwritten on refresh anyway, and keeping reads simple matters more here.
