with events as (

    select * from {{ ref('fct_listening_events') }}

)

select
    session_id,
    user_id,
    min(event_at)                                                   as session_started_at,
    max(event_at)                                                   as session_ended_at,
    cast(min(event_at) as date)                                     as session_date,
    round(sum(case when is_stream then ms_played end) / 60000.0, 1)     as minutes_listened,
    sum(case when is_stream then 1 else 0 end)                               as n_streams,
    sum(case when event_type = 'skip' then 1 else 0 end)                     as n_skips,
    sum(case when event_type = 'like' then 1 else 0 end)                     as n_likes,
    count(distinct case when is_stream then track_id end)               as n_unique_tracks,
    round(sum(case when event_type = 'skip' then 1 else 0 end)
          / nullif(sum(case when is_stream then 1 else 0 end), 0), 3)        as skip_rate,
    min_by(device, event_at)                                        as device,
    min_by(play_context, event_at)                                  as entry_play_context
from events
group by 1, 2
