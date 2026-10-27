{#
    Sales-led funnel by lead cohort month and lead source:
        lead → MQL → SQL → opportunity → closed won
    with stage conversion rates and median days between stages (velocity).
#}

with leads as (

    select * from {{ ref('stg_salesforce__leads') }}

),

opps as (

    select * from {{ ref('stg_salesforce__opportunities') }}

),

joined as (

    select
        {{ month_start('leads.created_at') }}                                   as month_start,
        leads.lead_source,
        leads.lead_id,
        leads.mql_at is not null                                                as is_mql,
        leads.sql_at is not null                                                as is_sql,
        opps.opportunity_id is not null                                         as has_opportunity,
        coalesce(opps.is_won, false)                                            as is_won,
        opps.amount_usd,
        {{ dbt.datediff('leads.created_at', 'leads.mql_at', 'day') }}           as days_lead_to_mql,
        {{ dbt.datediff('leads.mql_at', 'leads.sql_at', 'day') }}               as days_mql_to_sql,
        {{ dbt.datediff('leads.sql_at', 'opps.created_at', 'day') }}            as days_sql_to_opp,
        case when opps.is_closed then {{ dbt.datediff('opps.created_at', 'opps.close_date', 'day') }} end as days_opp_to_close
    from leads
    left join opps on opps.opportunity_id = leads.converted_opportunity_id

)

select
    month_start,
    lead_source,
    count(*)                                                                    as leads,
    sum(case when is_mql then 1 else 0 end)                                     as mqls,
    sum(case when is_sql then 1 else 0 end)                                     as sqls,
    sum(case when has_opportunity then 1 else 0 end)                            as opportunities,
    sum(case when is_won then 1 else 0 end)                                     as won_deals,
    coalesce(sum(case when has_opportunity then amount_usd end), 0)             as pipeline_usd,
    coalesce(sum(case when is_won then amount_usd end), 0)                      as won_usd,
    round(sum(case when is_mql then 1 else 0 end) / nullif(count(*), 0), 4)     as lead_to_mql_rate,
    round(sum(case when is_sql then 1 else 0 end)
          / nullif(sum(case when is_mql then 1 else 0 end), 0), 4)              as mql_to_sql_rate,
    round(sum(case when has_opportunity then 1 else 0 end)
          / nullif(sum(case when is_sql then 1 else 0 end), 0), 4)              as sql_to_opp_rate,
    avg(days_lead_to_mql)                                                       as avg_days_lead_to_mql,
    avg(days_mql_to_sql)                                                        as avg_days_mql_to_sql,
    avg(days_sql_to_opp)                                                        as avg_days_sql_to_opp,
    avg(days_opp_to_close)                                                      as avg_days_opp_to_close
from joined
group by 1, 2
