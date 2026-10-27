{{ config(materialized='table') }}

{#
    The outcomes marketing is measured against, on one grain:
      plg_signup          a new account (count only)
      plg_paid            first paid subscription, valued at first-year revenue (USD)
      enterprise_pipeline an opportunity is created, valued at its amount
      enterprise_won      an opportunity is closed-won, valued at its amount
    Enterprise conversions are keyed by the Lead that converted, so the lead's
    campaign responses can be credited.
#}

with first_paid as (

    select user_id, plan, monthly_price_eur, started_at
    from {{ ref('fct_subscriptions') }}
    where is_paid
    qualify row_number() over (partition by user_id order by started_at) = 1

),

converted_leads as (

    select leads.lead_id, opps.*
    from {{ ref('stg_salesforce__leads') }} as leads
    inner join {{ ref('stg_salesforce__opportunities') }} as opps
        on opps.opportunity_id = leads.converted_opportunity_id
    where true
    -- one lead per opportunity (the first one that converted)
    qualify row_number() over (partition by opps.opportunity_id order by leads.created_at, leads.lead_id) = 1

)

select
    {{ surrogate_key(["'plg_signup'", 'user_id']) }}            as conversion_id,
    'plg_signup'                                                as conversion_type,
    'plg'                                                       as motion,
    user_id                                                     as person_key,
    signed_up_at                                                as converted_at,
    cast(0 as {{ dbt.type_float() }})                           as value_usd
from {{ ref('stg_muse__users') }}

union all

select
    {{ surrogate_key(["'plg_paid'", 'user_id']) }},
    'plg_paid',
    'plg',
    user_id,
    started_at,
    round(monthly_price_eur * 12 * {{ var('muse_eur_to_usd') }}, 2)
from first_paid

union all

select
    {{ surrogate_key(["'enterprise_pipeline'", 'opportunity_id']) }},
    'enterprise_pipeline',
    'enterprise',
    lead_id,
    created_at,
    amount_usd
from converted_leads

union all

select
    {{ surrogate_key(["'enterprise_won'", 'opportunity_id']) }},
    'enterprise_won',
    'enterprise',
    lead_id,
    cast(close_date as timestamp),
    amount_usd
from converted_leads
where is_won
