{{ config(materialized='view') }}

{#
    Sessionisation: a new session starts when a listener has been inactive for
    more than `muse_session_timeout_minutes` (default 30) between streams.
    Engagement events (like, add_to_playlist, repeat) inherit the session of
    the stream they belong to.
#}

with events as (

    select * from {{ ref('stg_muse__listening_events') }}

),

flagged as (

    select
        *,
        case
            when lag(event_at) over (partition by user_id order by event_at, event_id) is null then 1
            when {{ dbt.datediff('lag(event_at) over (partition by user_id order by event_at, event_id)', 'event_at', 'second') }}
                 > {{ var('muse_session_timeout_minutes') }} * 60 then 1
            else 0
        end as is_new_session
    from events

),

numbered as (

    select
        *,
        sum(is_new_session) over (
            partition by user_id order by event_at, event_id
            rows between unbounded preceding and current row
        ) as user_session_number
    from flagged

)

select
    event_id,
    user_id,
    track_id,
    event_type,
    is_stream,
    event_at,
    event_date,
    ms_played,
    device,
    play_context,
    ingested_at,
    user_session_number,
    {{ surrogate_key(['user_id', 'user_session_number']) }} as session_id
from numbered
