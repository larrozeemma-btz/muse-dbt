{{ config(materialized='table') }}

{#
    Engagement per listener × track — the raw material of the history signal.
    Points per event type come from the `muse_event_points` var
    (play +1, repeat +2, like +3, add_to_playlist +3, skip -1): slide 10's
    "adjust based on skips, likes and repeats".
#}

select
    user_id,
    track_id,
    sum(case when event_type = 'play' then 1 else 0 end)             as n_plays,
    sum(case when event_type = 'skip' then 1 else 0 end)             as n_skips,
    sum(case when event_type = 'like' then 1 else 0 end)             as n_likes,
    sum(case when event_type = 'add_to_playlist' then 1 else 0 end)  as n_playlist_adds,
    sum(case when event_type = 'repeat' then 1 else 0 end)           as n_repeats,
    sum(case when is_stream then ms_played end)                 as ms_listened,
    sum({{ event_points('event_type') }})                   as engagement_points,
    min(event_at)                                           as first_listened_at,
    max(event_at)                                           as last_listened_at
from {{ ref('stg_muse__listening_events') }}
where track_id in (select track_id from {{ ref('stg_spotify__tracks') }})
group by 1, 2
