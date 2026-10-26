with tracks as (

    select * from {{ ref('stg_muse__tracks') }}

),

artists as (

    select * from {{ ref('stg_muse__artists') }}

),

genres as (

    select * from {{ ref('stg_muse__genres') }}

),

popularity as (

    select * from {{ ref('int_track_popularity') }}

)

select
    tracks.track_id,
    tracks.track_title,
    tracks.artist_id,
    artists.artist_name,
    tracks.genre_name,
    genres.parent_genre,
    tracks.release_date,
    tracks.duration_seconds,
    tracks.is_explicit,
    popularity.n_listeners,
    popularity.n_plays,
    popularity.n_likes,
    popularity.n_skips,
    round(popularity.n_skips / nullif(popularity.n_plays + popularity.n_skips, 0), 3) as skip_rate,
    popularity.popularity_score
from tracks
left join artists    using (artist_id)
left join genres     using (genre_name)
left join popularity using (track_id)
