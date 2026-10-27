{#
    Enterprise pipeline by quarter and channel, two lenses finance and sales
    leadership both ask for:
      sourced    — credited to the channel of the touch that created the lead (first touch)
      influenced — full amount counted for every channel that touched the deal
                   before the opportunity was created (adds up to more than 100 %, by design)
#}

with touches as (

    select * from {{ ref('fct_marketing_attribution') }}
    where conversion_type in ('enterprise_pipeline', 'enterprise_won')

),

quarters as (

    select
        cast({{ dbt.date_trunc('quarter', 'converted_at') }} as date)          as quarter_start,
        conversion_type,
        channel,
        sum(case when attribution_model = 'first_touch' then credited_value_usd else 0 end) as sourced_usd,
        sum(case when attribution_model = 'linear' then credited_value_usd / credit else 0 end) as influenced_usd,
        count(distinct case when attribution_model = 'linear' then conversion_id end) as influenced_deals
    from touches
    group by 1, 2, 3

)

select
    quarter_start,
    channel,
    sum(case when conversion_type = 'enterprise_pipeline' then sourced_usd else 0 end)     as sourced_pipeline_usd,
    sum(case when conversion_type = 'enterprise_pipeline' then influenced_usd else 0 end)  as influenced_pipeline_usd,
    sum(case when conversion_type = 'enterprise_pipeline' then influenced_deals else 0 end) as influenced_opportunities,
    sum(case when conversion_type = 'enterprise_won' then sourced_usd else 0 end)          as sourced_bookings_usd,
    sum(case when conversion_type = 'enterprise_won' then influenced_usd else 0 end)       as influenced_bookings_usd
from quarters
group by 1, 2
