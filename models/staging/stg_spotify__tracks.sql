{#
    One row per track. The source repeats a track once per genre it is listed
    under; genre membership is kept in `stg_spotify__track_genres`.
#}

with source as (

    select * from {{ source('spotify', 'spotify_tracks') }}
    where track_id is not null
      and artists is not null   -- one fully empty row in the source

),

deduplicated as (

    select *
    from source
    where true  -- (BigQuery wants a WHERE/GROUP BY next to QUALIFY)
    qualify row_number() over (partition by track_id order by popularity desc, source_row_number) = 1

)

select
    track_id,
    trim(track_name)                        as track_title,
    trim(album_name)                        as album_name,
    artists                                 as artists_raw,
    track_genre                             as primary_genre,
    popularity                              as spotify_popularity,
    duration_ms,
    round(duration_ms / 1000.0, 0)          as duration_seconds,
    explicit                                as is_explicit,
    danceability,
    energy,
    valence,
    acousticness,
    instrumentalness,
    speechiness,
    liveness,
    loudness                                as loudness_db,
    tempo                                   as tempo_bpm,
    nullif({{ adapter.quote('key') }}, -1)   as musical_key,
    {{ adapter.quote('mode') }} = 1           as is_major_mode,
    time_signature
from deduplicated
