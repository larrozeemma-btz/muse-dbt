{{ config(materialized='table') }}

{#
    POPULARITY signal (20 % of the MUSE score).

    Blends two views of "widely enjoyed":
      - Spotify's global popularity (real, from the catalog)
      - MUSE in-app reach: percentile of distinct listeners on the platform
    Tracks nobody on MUSE has played rely on Spotify popularity alone.
#}

with tracks as (

    select track_id, spotify_popularity from {{ ref('stg_spotify__tracks') }}

),

in_app as (

    select
        track_id,
        count(distinct case when n_plays > 0 then user_id end)  as n_listeners,
        sum(n_plays)                                         as n_plays,
        sum(n_skips)                                         as n_skips,
        sum(n_likes)                                         as n_likes
    from {{ ref('int_user_track_engagement') }}
    group by 1

),

ranked as (

    select
        *,
        round(100 * percent_rank() over (order by n_listeners, n_likes), 1) as in_app_percentile
    from in_app
    where n_listeners > 0

)

select
    tracks.track_id,
    tracks.spotify_popularity,
    coalesce(in_app.n_listeners, 0)     as n_listeners,
    coalesce(in_app.n_plays, 0)         as n_plays,
    coalesce(in_app.n_skips, 0)         as n_skips,
    coalesce(in_app.n_likes, 0)         as n_likes,
    ranked.in_app_percentile,
    case
        when ranked.in_app_percentile is null then tracks.spotify_popularity
        else round(0.5 * tracks.spotify_popularity + 0.5 * ranked.in_app_percentile, 1)
    end                                 as popularity_score
from tracks
left join in_app using (track_id)
left join ranked using (track_id)
