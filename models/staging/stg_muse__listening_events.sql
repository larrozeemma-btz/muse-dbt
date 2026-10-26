with source as (

    select * from {{ ref('raw_listening_events') }}

),

deduplicated as (

    -- at-least-once ingestion re-sends some events: keep one row per event_id
    select *
    from source
    qualify row_number() over (partition by event_id order by event_at) = 1

)

select
    event_id,
    user_id,
    track_id,
    lower(trim(event_type))             as event_type,
    event_at,
    cast(event_at as date)              as event_date,
    ms_played
from deduplicated
