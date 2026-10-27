{#
    The one table the weekly marketing / exec review reads: spend, top-of-funnel,
    conversions, efficiency and pipeline for each ISO week, with week-over-week change.
#}

with weeks as (

    select distinct week_start
    from {{ ref('dim_date') }}
    -- last complete week only: a half-loaded week reads as a collapse in the review
    where date_day between date '2024-01-01' and date '{{ var("muse_reporting_cutoff_date") }}'
      and week_start <= {{ date_add_days("date '" ~ var('muse_reporting_cutoff_date') ~ "'", -6) }}

),

spend as (

    select {{ date_add_days('spend_date', '1 - (' ~ iso_day_of_week('spend_date') ~ ')') }} as week_start,
           sum(spend_usd)                                                       as spend_usd,
           sum(case when motion = 'plg' then spend_usd else 0 end)              as plg_spend_usd,
           sum(case when motion = 'enterprise' then spend_usd else 0 end)       as enterprise_spend_usd
    from {{ ref('fct_ad_spend') }}
    group by 1

),

conversions as (

    select
        {{ date_add_days('cast(converted_at as date)', '1 - (' ~ iso_day_of_week('cast(converted_at as date)') ~ ')') }} as week_start,
        sum(case when conversion_type = 'plg_signup' then 1 else 0 end)                         as signups,
        sum(case when conversion_type = 'plg_paid' then 1 else 0 end)                           as paid_conversions,
        sum(case when conversion_type = 'enterprise_pipeline' then value_usd else 0 end)        as pipeline_created_usd,
        sum(case when conversion_type = 'enterprise_won' then value_usd else 0 end)             as closed_won_usd
    from {{ ref('int_marketing_conversions') }}
    group by 1

),

leads as (

    select
        {{ date_add_days('cast(created_at as date)', '1 - (' ~ iso_day_of_week('cast(created_at as date)') ~ ')') }} as week_start,
        count(*)                                                as new_leads,
        sum(case when mql_at is not null then 1 else 0 end)     as new_mqls
    from {{ ref('stg_salesforce__leads') }}
    group by 1

),

weekly as (

    select
        weeks.week_start,
        coalesce(spend.spend_usd, 0)                    as spend_usd,
        coalesce(spend.plg_spend_usd, 0)                as plg_spend_usd,
        coalesce(spend.enterprise_spend_usd, 0)         as enterprise_spend_usd,
        coalesce(conversions.signups, 0)                as signups,
        coalesce(conversions.paid_conversions, 0)       as paid_conversions,
        coalesce(leads.new_leads, 0)                    as new_leads,
        coalesce(leads.new_mqls, 0)                     as new_mqls,
        coalesce(conversions.pipeline_created_usd, 0)   as pipeline_created_usd,
        coalesce(conversions.closed_won_usd, 0)         as closed_won_usd
    from weeks
    left join spend       using (week_start)
    left join conversions using (week_start)
    left join leads       using (week_start)

)

select
    *,
    -- each motion's spend is divided by that motion's outcomes: enterprise events
    -- and ABM never inflate the consumer CAC, and vice versa
    round(plg_spend_usd / nullif(paid_conversions, 0), 2)                                   as blended_cac_usd,
    round(plg_spend_usd / nullif(signups, 0), 2)                                            as cost_per_signup_usd,
    round(pipeline_created_usd / nullif(enterprise_spend_usd, 0), 2)                        as pipeline_per_enterprise_dollar,
    round((signups - lag(signups) over (order by week_start))
          / nullif(lag(signups) over (order by week_start), 0), 3)                          as signups_wow,
    round((spend_usd - lag(spend_usd) over (order by week_start))
          / nullif(lag(spend_usd) over (order by week_start), 0), 3)                        as spend_wow,
    round((pipeline_created_usd - lag(pipeline_created_usd) over (order by week_start))
          / nullif(lag(pipeline_created_usd) over (order by week_start), 0), 3)             as pipeline_wow
from weekly
