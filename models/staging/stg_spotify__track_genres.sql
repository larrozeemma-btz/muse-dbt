select distinct
    track_id,
    track_genre as genre_name
from {{ source('spotify', 'spotify_tracks') }}
where track_id is not null
  and artists is not null
