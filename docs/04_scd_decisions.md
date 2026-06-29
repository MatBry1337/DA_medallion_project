# SCD Decisions

SCD type per dimension attribute, with the reason. The rule of thumb: version
an attribute (SCD2) only when a play must be attributed to the value it had **at
play time**; otherwise overwrite (SCD1) or freeze (SCD0).

## dim_user

| Attribute | SCD | Why                                                                                                                                             |
|---|---|-------------------------------------------------------------------------------------------------------------------------------------------------|
| plan_code (tier) | **SCD2** | The heart of the question. Listening must be counted under the tier the user was on *when they played*, so we keep the history of tier changes. |
| monthly_price | **SCD2** | Tracks revenue per period. A price change on the same tier still needs the old price for plays before the change.                               |
| country | **SCD2** | Region analysis must reflect where the user was at play time, not where they are now.                                                           |
| email | SCD1 | Only the current value matters, old emails don't change any analysis.                                                                           |
| display_name | SCD1 | Cosmetic, current value only.                                                                                                                   |
| age_band | SCD1 | Used as a current attribute, we don't analyse "age band at play time".                                                                          |
| signup_date | SCD0 | A fact about the user that never changes.                                                                                                       |
| marketing_source | SCD0 | The acquisition channel is set once.                                                                                                            |

## dim_content

All SCD1 except `release_date`. Content attributes (`title`, `content_type`,
`artist_name`, `is_explicit`) describe the track as it is now, a retitle or
re-tag doesn't change how past listening should be counted, so we overwrite.
`release_date` is SCD0 — it never changes.

## dim_device

`device_type` and `os_version` are SCD1 — we only care about the current
description of a device, not its history.

## dim_date

A calendar, no SCD. The rows are generated once and never change.
