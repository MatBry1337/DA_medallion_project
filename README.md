# SonicWave Analytics Platform

## The question

For each plan tier, how much do users actually listen while they're on
that tier — and which paying users look like they're drifting toward churn
because their listening keeps dropping?

## Why this exists

Right now product, marketing and finance all query SonicWave's live app
database directly. It's slow (their big aggregations fight the app for
resources), and worse, it's *wrong over time* — the OLTP database only
knows each user's **current** plan, so a question like "how much did people
listen while on the Free tier?" silently counts last year's plays under
whatever tier the user happens to be on today.

This project builds the analytical layer that fixes both: raw events land
in **Bronze**, get cleaned and conformed in **Silver** (where we keep the
*history* of who was on which plan and when), and are modelled into a
**Gold** star that answers the business questions correctly, repeatably,
and fast.

## Architecture

Raw events land in **Bronze** (append-only, untouched), get typed,
deduplicated and historized in **Silver**, and are modelled into a
**Gold** star that answers the question with point-in-time correctness.
Full layer-by-layer detail in [`docs/02_model_diagram.md`](docs/02_model_diagram.md).

```mermaid
flowchart LR
    SRC["public.* (OLTP)<br/>current plan only"] --> B["bronze.playback_raw<br/>append-only · provenance"]
    B -->|"idempotent MERGE · dedup · late flag"| V["silver.playback (typed)<br/>silver.dim_user_hist (SCD2)"]
    V -->|"assign SK · point-in-time join · reconcile"| G["gold star<br/>fact_playback + dims<br/>partitioned, no indexes"]
```

## The star schema

```mermaid
erDiagram
    DIM_USER    ||--o{ FACT_PLAYBACK : "attributed to (point-in-time)"
    DIM_CONTENT ||--o{ FACT_PLAYBACK : "describes"
    DIM_DEVICE  ||--o{ FACT_PLAYBACK : "played on"
    DIM_DATE    ||--o{ FACT_PLAYBACK : "occurred on"

    FACT_PLAYBACK {
        bigint      event_id     PK "natural key (+ part of grain)"
        timestamptz started_at   PK "partition key (monthly)"
        int         user_sk      FK
        int         content_sk   FK
        int         device_sk    FK
        int         date_key     FK
        int         minutes_played
        int         play_count
        int         completed_plays
    }
    DIM_USER {
        int         user_sk    PK "surrogate"
        int         user_id       "natural key"
        text        country       "SCD2"
        varchar     plan_code     "SCD2"
        numeric     monthly_price "SCD2"
        timestamptz valid_from
        timestamptz valid_to
        boolean     is_current
    }
    DIM_CONTENT {
        int     content_sk    PK "surrogate"
        int     content_id       "natural key"
        varchar title
        varchar content_type
        text    artist_name
        int     duration_seconds
        date    release_date
        boolean is_explicit
    }
    DIM_DEVICE {
        int     device_sk   PK "surrogate"
        bigint  device_id      "natural key"
        varchar device_type
        varchar os_version
    }
    DIM_DATE {
        int  date_key PK
        date full_date
        int  year
        int  month
        int  iso_week
        text weekday
    }
```

## How to run

#TODO
