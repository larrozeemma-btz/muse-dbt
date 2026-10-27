{#
    Identity stitching: a browser cookie (anonymous_id) becomes a known user the
    first time a session carries both ids — the signup session. Every earlier
    anonymous visit from that browser is then credited to the user's journey.
#}

select
    anonymous_id,
    user_id,
    min_session_at  as identified_at
from (
    select anonymous_id, user_id, min(session_started_at) as min_session_at
    from {{ ref('stg_web__sessions') }}
    where user_id is not null
    group by 1, 2
) as pairs
where true
qualify row_number() over (partition by anonymous_id order by min_session_at, user_id) = 1
