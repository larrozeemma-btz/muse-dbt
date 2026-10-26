with tracks as (

    select * from {{ ref('stg_spotify__tracks') }}

),

primary_artist as (

    select track_id, artist_id, artist_name
    from {{ ref('stg_spotify__track_artists') }}
    where is_primary_artist

),

n_artists as (

    select track_id, count(*) as n_artists
    from {{ ref('stg_spotify__track_artists') }}
    group by 1

),

families as (

    select * from {{ ref('genre_families') }}

),

popularity as (

    select * from {{ ref('int_track_popularity') }}

)

select
    tracks.track_id,
    tracks.track_title,
    tracks.album_name,
    primary_artist.artist_id                as primary_artist_id,
    primary_artist.artist_name              as primary_artist_name,
    tracks.artists_raw                      as artists_display,
    n_artists.n_artists,
    tracks.primary_genre,
    families.genre_family,
    tracks.duration_seconds,
    tracks.is_explicit,
    tracks.danceability,
    tracks.energy,
    tracks.valence,
    tracks.acousticness,
    tracks.instrumentalness,
    tracks.speechiness,
    tracks.tempo_bpm,
    tracks.loudness_db,
    tracks.musical_key,
    tracks.is_major_mode,
    -- simple mood quadrant from the valence/energy plane
    case
        when tracks.energy >= 0.5 and tracks.valence >= 0.5 then 'happy & energetic'
        when tracks.energy >= 0.5                           then 'intense'
        when tracks.valence >= 0.5                          then 'calm & positive'
        else 'melancholic'
    end                                     as mood,
    popularity.spotify_popularity,
    popularity.n_listeners                  as muse_listeners,
    popularity.n_plays                      as muse_plays,
    popularity.n_likes                      as muse_likes,
    round(popularity.n_skips / nullif(popularity.n_plays + popularity.n_skips, 0), 3) as muse_skip_rate,
    popularity.popularity_score
from tracks
left join primary_artist using (track_id)
left join n_artists using (track_id)
left join families on families.genre_name = tracks.primary_genre
left join popularity using (track_id)
