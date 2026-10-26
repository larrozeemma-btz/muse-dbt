{{
    config(
        materialized='incremental',
        unique_key='event_id',
        incremental_strategy='delete+insert'
    )
}}

{#
    Event-grain fact table. Incremental: on each run only events newer than
    what is already loaded are processed — the pattern you'd use on a real,
    ever-growing listening stream.
#}

with events as (

    select * from {{ ref('stg_muse__listening_events') }}

    {% if is_incremental() %}
    where event_at > (select max(event_at) from {{ this }})
    {% endif %}

),

tracks as (

    select track_id, artist_id, genre_name, duration_ms
    from {{ ref('stg_muse__tracks') }}

)

select
    events.event_id,
    events.user_id,
    events.track_id,
    tracks.artist_id,
    tracks.genre_name,
    events.event_type,
    events.event_at,
    events.event_date,
    events.ms_played,
    round(events.ms_played / nullif(tracks.duration_ms, 0), 3)     as completion_rate,
    {{ event_points('events.event_type') }}                         as engagement_points
from events
left join tracks using (track_id)
