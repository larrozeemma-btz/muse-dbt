{#
    POPULARITY signal (20 % of the MUSE score).

    A broad, listener-independent signal: tracks are ranked by how many
    distinct listeners completed a play, and that rank is turned into a
    0–100 percentile. Tracks nobody has played yet score 0.
#}

with engagement as (

    select * from {{ ref('int_user_track_engagement') }}

),

tracks as (

    select track_id from {{ ref('stg_muse__tracks') }}

),

listeners as (

    select
        track_id,
        count(distinct user_id) filter (where n_plays > 0)  as n_listeners,
        sum(n_plays)                                         as n_plays,
        sum(n_likes)                                         as n_likes,
        sum(n_skips)                                         as n_skips
    from engagement
    group by 1

)

select
    tracks.track_id,
    coalesce(listeners.n_listeners, 0)  as n_listeners,
    coalesce(listeners.n_plays, 0)      as n_plays,
    coalesce(listeners.n_likes, 0)      as n_likes,
    coalesce(listeners.n_skips, 0)      as n_skips,
    case
        when coalesce(listeners.n_listeners, 0) = 0 then 0
        else round(100 * percent_rank() over (
            order by coalesce(listeners.n_listeners, 0), coalesce(listeners.n_likes, 0)
        ), 1)
    end as popularity_score
from tracks
left join listeners using (track_id)
