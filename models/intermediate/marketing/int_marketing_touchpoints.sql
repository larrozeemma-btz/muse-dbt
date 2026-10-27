{{ config(materialized='table') }}

{#
    Every marketing touch, both motions, on one grain:
      - PLG: web sessions, keyed by the stitched user (or the cookie if never identified)
      - Enterprise: CRM campaign responses, keyed by the Lead
#}

with web as (

    select
        sessions.session_id                                         as touchpoint_id,
        'plg'                                                       as motion,
        'web_session'                                               as touch_type,
        coalesce(sessions.user_id, identity.user_id, sessions.anonymous_id) as person_key,
        coalesce(sessions.user_id, identity.user_id) is not null    as is_identified,
        sessions.session_started_at                                 as touched_at,
        sessions.channel,
        sessions.utm_campaign                                       as campaign_code
    from {{ ref('int_web_sessions_channeled') }} as sessions
    left join {{ ref('int_identity_map') }} as identity
        on identity.anonymous_id = sessions.anonymous_id

),

crm as (

    select
        campaign_member_id                                          as touchpoint_id,
        'enterprise'                                                as motion,
        'campaign_response'                                         as touch_type,
        lead_id                                                     as person_key,
        true                                                        as is_identified,
        responded_at                                                as touched_at,
        channel,
        campaign_code
    from {{ ref('stg_salesforce__campaign_members') }}

)

select * from web
union all
select * from crm
