{#
    LISTENING HISTORY building blocks: how much a listener engaged with each
    artist and each genre, normalised to 0–100 against that listener's own
    favourite (so heavy and light listeners are comparable).
#}

with engagement as (

    select * from {{ ref('int_user_track_engagement') }}

),

tracks as (

    select * from {{ ref('stg_muse__tracks') }}

),

enriched as (

    select
        engagement.user_id,
        tracks.artist_id,
        tracks.genre_name,
        engagement.engagement_points
    from engagement
    inner join tracks using (track_id)

),

by_artist as (

    select
        user_id,
        'artist'                                as affinity_type,
        artist_id                               as affinity_key,
        greatest(sum(engagement_points), 0)     as raw_points
    from enriched
    group by 1, 2, 3

),

by_genre as (

    select
        user_id,
        'genre'                                 as affinity_type,
        genre_name                              as affinity_key,
        greatest(sum(engagement_points), 0)     as raw_points
    from enriched
    group by 1, 2, 3

),

unioned as (

    select * from by_artist
    union all
    select * from by_genre

)

select
    user_id,
    affinity_type,
    affinity_key,
    raw_points,
    round(
        100.0 * raw_points
        / nullif(max(raw_points) over (partition by user_id, affinity_type), 0)
    , 1) as affinity_score
from unioned
