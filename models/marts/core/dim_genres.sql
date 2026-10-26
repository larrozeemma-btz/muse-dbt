select
    genre_name,
    parent_genre
from {{ ref('stg_muse__genres') }}
