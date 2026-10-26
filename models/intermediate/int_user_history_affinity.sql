{{ config(materialized='table') }}

{#
    LISTENING HISTORY building blocks: engagement per listener × artist and
    listener × genre, normalised 0–100 against the listener's own favourite,
    so a light listener's favourite artist scores as high as a heavy one's.
#}

with engagement as (

    select * from {{ ref('int_user_track_engagement') }}

),

by_artist as (

    select
        engagement.user_id,
        'artist'                                        as affinity_type,
        track_artists.artist_id                         as affinity_key,
        greatest(sum(engagement.engagement_points), 0)  as raw_points
    from engagement
    inner join {{ ref('stg_spotify__track_artists') }} as track_artists using (track_id)
    group by 1, 2, 3

),

by_genre as (

    select
        engagement.user_id,
        'genre'                                         as affinity_type,
        tracks.primary_genre                            as affinity_key,
        greatest(sum(engagement.engagement_points), 0)  as raw_points
    from engagement
    inner join {{ ref('stg_spotify__tracks') }} as tracks using (track_id)
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
    coalesce(round(
        100.0 * raw_points / nullif(max(raw_points) over (partition by user_id, affinity_type), 0)
    , 1), 0) as affinity_score
from unioned
