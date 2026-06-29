# Business Question

For each plan tier, how much listening happens while users are actually on that tier (counted at the tier valid when each play occurred),
and which currently-paying users are at churn risk from a sustained decline in their listening?


| # | Question                                                                                                                                                                                                        | Forces |
|---|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------|
| 1 | Total minutes played per plan tier per month, attributing each play to the tier the user was on **at play time**                                                                                                | point-in-time SCD2, partition pruning |
| 2 | For each user, compare their weekly minutes listened to the previous week (LAG ordered by week, partitioned by user) to flag users whose listening has declined for N weeks running."                           | rolling window (LAG/LEAD) |
| 3 | Paying users with no playback in the last 30 days                                                                                                                                                               | anti-join |
| 4 | Compare total minutes per plan tier computed two ways — attributing each play to the tier the user was on at play time vs to the user's current tier — and show the two totals differ, proving the SCD2 history | point-in-time vs naive contrast |
| 5 | Total listening minutes for a single month (e.g. 2024-03), with EXPLAIN ANALYZE showing the planner reads only that month's partition.                                                                          | partition benefit |
| 6 | A wide, flat one-row-per-play table derived from the star, enriched with user, plan tier (at play time), content/artist, device, and date attributes — for ad-hoc analysis.                                     | feeds the OBT |
