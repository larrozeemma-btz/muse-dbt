with credits as (

    select * from {{ ref('stg_spotify__track_artists') }}

),

tracks as (

    select * from {{ ref('stg_spotify__tracks') }}

),

popularity as (

    select * from {{ ref('int_track_popularity') }}

),

names as (

    -- the same artist can be spelled with different casing across tracks
    select artist_id, artist_name
    from credits
    group by 1, 2
    qualify row_number() over (partition by artist_id order by count(*) desc, artist_name) = 1

),

top_genre as (

    select credits.artist_id, tracks.primary_genre as main_genre
    from credits
    inner join tracks using (track_id)
    group by 1, 2
    qualify row_number() over (partition by credits.artist_id order by count(*) desc, tracks.primary_genre) = 1

),

stats as (

    select
        credits.artist_id,
        count(distinct credits.track_id)                                as n_tracks,
        count(distinct case when not credits.is_primary_artist then credits.track_id end) as n_features,
        round(avg(popularity.spotify_popularity), 1)                    as avg_spotify_popularity,
        max(popularity.spotify_popularity)                              as max_spotify_popularity,
        sum(popularity.n_plays)                                         as muse_plays,
        sum(popularity.n_likes)                                         as muse_likes
    from credits
    inner join popularity using (track_id)
    group by 1

)

select
    names.artist_id,
    names.artist_name,
    top_genre.main_genre,
    stats.n_tracks,
    stats.n_features,
    stats.avg_spotify_popularity,
    stats.max_spotify_popularity,
    stats.muse_plays,
    stats.muse_likes
from names
left join top_genre using (artist_id)
left join stats using (artist_id)
