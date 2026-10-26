{#
    Engagement points a listener has given to each track they interacted with.
    Points per event type are configured in the `muse_event_points` var
    (play +1, repeat +2, like +3, skip -1) — the "skips, likes and repeats"
    feedback loop from slide 10.
#}

with events as (

    select * from {{ ref('stg_muse__listening_events') }}

)

select
    user_id,
    track_id,
    count(*)                                            as n_events,
    count(*) filter (where event_type = 'play')         as n_plays,
    count(*) filter (where event_type = 'skip')         as n_skips,
    count(*) filter (where event_type = 'like')         as n_likes,
    count(*) filter (where event_type = 'repeat')       as n_repeats,
    sum({{ event_points('event_type') }})               as engagement_points,
    min(event_at)                                       as first_listened_at,
    max(event_at)                                       as last_listened_at
from events
group by 1, 2
