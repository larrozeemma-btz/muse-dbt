{#- The BigQuery sandbox forbids DML (MERGE), so there the model is rebuilt as a table. -#}
{%- set bq_sandbox = target.type == 'bigquery' and env_var('DBT_BQ_SANDBOX', 'false') | lower == 'true' -%}
{{
    config(
        materialized='table' if bq_sandbox else 'incremental',
        unique_key='event_id',
        incremental_strategy='merge' if target.type == 'bigquery' else 'delete+insert',
        partition_by={'field': 'event_date', 'data_type': 'date', 'granularity': 'month'} if target.type == 'bigquery' else none,
        cluster_by=['user_id', 'track_id'] if target.type == 'bigquery' else none
    )
}}

{#
    Event-grain fact table, incremental on *ingestion* time rather than event
    time: mobile clients upload offline listening days late, so filtering on
    event_at would silently drop late arrivals. A 3-day lookback re-processes
    the tail in case sessions were re-stitched by late events.
#}

with events as (

    select * from {{ ref('int_listening_events_sessionized') }}

    {% if is_incremental() %}
    where ingested_at > (select {{ timestamp_add_days('max(ingested_at)', -3) }} from {{ this }})
    {% endif %}

),

tracks as (

    select track_id, primary_genre, duration_seconds
    from {{ ref('dim_tracks') }}

)

select
    events.event_id,
    events.session_id,
    events.user_id,
    events.track_id,
    tracks.primary_genre                                            as genre_name,
    events.event_type,
    events.is_stream,
    events.event_at,
    events.event_date,
    extract(hour from events.event_at)                              as event_hour,
    events.ms_played,
    round(events.ms_played / 1000.0 / nullif(tracks.duration_seconds, 0), 3) as completion_rate,
    events.device,
    events.play_context,
    {{ event_points('events.event_type') }}                         as engagement_points,
    tracks.track_id is null                                         as is_orphan_track,
    events.ingested_at,
    {{ dbt.datediff('events.event_at', 'events.ingested_at', 'hour') }} as ingestion_lag_hours
from events
left join tracks using (track_id)
