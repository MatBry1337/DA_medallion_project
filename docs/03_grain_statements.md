# Grain Statements

For each plan tier, how much listening happens while users are actually on that tier (counted at the tier valid when each play occurred),
and which currently-paying users are at churn risk from a sustained decline in their listening?

# playback fact 

One row per playback event - a single user playing a single piece of content at a point in time.
Flavour: transaction
Measures: minutes_played, play_count, completed_plays
Additivity: Fully additive, we can SUM per every dimension
