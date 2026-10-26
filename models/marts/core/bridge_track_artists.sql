select
    track_id,
    artist_id,
    billing_position,
    is_primary_artist
from {{ ref('stg_spotify__track_artists') }}
