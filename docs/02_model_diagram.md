# Model Diagrams

## Star schema (Mermaid)

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

    DIM_DATE {
        int  date_key PK
        date full_date
        int  year
        int  month
        int  iso_week
        text weekday
    }

    DIM_USER {
        int         user_sk    PK "surrogate"
        int         user_id       "natural key - traceability"
        text        country       "SCD2"
        varchar     plan_code     "SCD2"
        numeric     monthly_price "SCD2"
        timestamptz valid_from
        timestamptz valid_to
        boolean     is_current
    }

    DIM_CONTENT {
        int         content_sk    PK "surrogate"
        int         content_id    "natural key - traceability"
        varchar     title
        varchar     content_type
        text        artist_name
        int         duration_seconds
        date        release_date
        boolean     is_explicit
    }

    DIM_DEVICE {
        int         device_sk    PK "surrogate"
        bigint      device_id    "natural key - traceability"
        varchar     device_type
        varchar     os_version
    }
```
## Bronze -> Silver -> Gold flow

```mermaid
flowchart TD
    subgraph SRC["public.* — SonicWave OLTP (source)"]
        S1["play_events<br/>(raw playback)"]
        S2["users / subscriptions<br/>(current plan only)"]
        S3["content / devices"]
    end

    subgraph BRONZE["bronze — raw landing (append-only, never edited)"]
        B1["playback_raw<br/>permissive types · raw_payload<br/>+ provenance: ingested_at, source_file"]
    end

    subgraph SILVER["silver — conform + historize"]
        V1["playback<br/>typed · PK/NOT NULL/CHECK<br/>dedup ROW_NUMBER() rn=1<br/>event_time vs ingestion_time + is_late flag"]
        V2["dim_user_hist (SCD2)<br/>natural key + valid_from/valid_to/is_current<br/>NO surrogate key yet · gated on source freshness"]
    end

    subgraph GOLD["gold — the star (no indexes)"]
        G1["dim_user (SCD2, SK)<br/>dim_content · dim_device · dim_date"]
        G2["fact_playback<br/>PARTITIONED monthly by started_at<br/>grain = composite PK (event_id, started_at)"]
    end

    S1 --> B1
    S2 --> B1
    B1 -->|"idempotent MERGE"| V1
    S2 -.->|"change history"| V2
    S3 -.-> G1
    V2 -->|"project + assign SK"| G1
    V1 -->|"point-in-time join:<br/>tier valid AT event_time<br/>+ reconcile vs source"| G2
    G1 --> G2
```

### What each layer does to the data


**Bronze** `playback_raw` | Lands the raw event stream append-only with permissive types so malformed rows land instead of erroring; adds provenance (`ingested_at`, `source_file`, `raw_payload`). Never cleans, types, dedups, or edits. The immutable record of "what arrived". 
**Silver** `playback` | Casts to real types with PK/NOT NULL/CHECK, idempotent `MERGE` from Bronze, dedups with `ROW_NUMBER() … rn=1`, separates `event_time` from `ingestion_time` and flags late-arriving rows. No surrogate keys, no star shape.
**Silver** `dim_user_hist` | Historizes the dimension as **SCD2** (natural key + `valid_from`/`valid_to`/`is_current`), gates out-of-order changes on a source freshness key, not arrival order. No surrogate key yet (that's Gold's job).
**Gold** dims | Project SCD2 dims from Silver and **assign surrogate keys**; build generated `dim_date` and current-state `dim_device` directly.
**Gold** `fact_playback` | Idempotent load that resolves each event to the dimension version **valid at event time** (three-predicate time-aware join), partitioned monthly by `started_at`, reconciles fact rows vs source, a windowed `DELETE`-then-`INSERT` refresh absorbs late data.
