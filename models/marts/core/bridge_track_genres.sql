select
    track_genres.track_id,
    track_genres.genre_name,
    track_genres.genre_name = tracks.primary_genre as is_primary_genre
from {{ ref('stg_spotify__track_genres') }} as track_genres
inner join {{ ref('stg_spotify__tracks') }} as tracks using (track_id)
