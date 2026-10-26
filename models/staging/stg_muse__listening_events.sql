{#
    Cleans the client event stream:
      - parses both SDK timestamp formats (ISO-8601 with Z, and plain)
      - normalises event_type casing
      - drops logged-out events (no user)
      - removes duplicate deliveries, keeping the first ingestion
#}

with source as (

    select * from {{ source('muse_app', 'listening_events') }}
    where user_id is not null

),

parsed as (

    select
        event_id,
        user_id,
        track_id,
        lower(trim(event_type))                                         as event_type,
        {{ parse_event_timestamp('event_at') }}                       as event_at,
        ms_played,
        device,
        context                                                         as play_context,
        cast(ingested_at as timestamp)                                  as ingested_at
    from source

)

select
    *,
    cast(event_at as date)                                              as event_date,
    event_type in ('play', 'skip')                                      as is_stream
from parsed
where event_id is not null
qualify row_number() over (partition by event_id order by ingested_at) = 1
