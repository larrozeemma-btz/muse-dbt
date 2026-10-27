{#
    Normalises UTM parameters: lower-case, trimmed, blanks and "(not set)" → null,
    so the channel grouping rules only have to deal with clean values.
#}

with source as (

    select * from {{ source('web_analytics', 'web_sessions') }}

)

select
    session_id,
    anonymous_id,
    user_id,
    cast(replace(replace(session_started_at, 'T', ' '), 'Z', '') as timestamp)  as session_started_at,
    nullif(nullif(lower(trim(utm_source)), ''), '(not set)')                     as utm_source,
    nullif(nullif(lower(trim(utm_medium)), ''), '(not set)')                     as utm_medium,
    nullif(lower(trim(utm_campaign)), '')                                        as utm_campaign,
    landing_page,
    device_type
from source
