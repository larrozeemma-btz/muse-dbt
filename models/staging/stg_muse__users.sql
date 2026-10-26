with source as (

    select * from {{ ref('raw_users') }}

)

select
    user_id,
    username,
    upper(trim(country))                as country_code,
    lower(trim(subscription_plan))      as subscription_plan,
    cast(signed_up_at as timestamp)     as signed_up_at,
    birth_year
from source
