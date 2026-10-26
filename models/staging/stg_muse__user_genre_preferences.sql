select
    user_id,
    lower(trim(genre_name))                 as genre_name,
    affinity,
    cast(declared_at as timestamp)          as declared_at
from {{ source('muse_app', 'onboarding_genre_preferences') }}
