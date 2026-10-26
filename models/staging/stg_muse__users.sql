select
    user_id,
    cast(signed_up_at as timestamp)         as signed_up_at,
    upper(trim(country))                    as country_code,
    birth_year,
    acquisition_channel,
    primary_device,
    cast(deleted_at as timestamp)           as deleted_at
from {{ source('muse_app', 'app_users') }}
