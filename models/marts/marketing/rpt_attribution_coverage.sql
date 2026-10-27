{#
    How much of each outcome the touchpoint data can explain. Conversions with
    no touch in the lookback window are not attributable — reporting that share
    keeps everyone honest about what "attributed" numbers leave out.
#}

with conversions as (

    select conversion_id, conversion_type, {{ month_start('converted_at') }} as month_start, value_usd
    from {{ ref('int_marketing_conversions') }}

),

attributed as (

    select distinct conversion_id from {{ ref('int_attribution_weights') }}

)

select
    conversions.month_start,
    conversions.conversion_type,
    count(*)                                                                    as conversions,
    sum(case when attributed.conversion_id is not null then 1 else 0 end)       as attributable_conversions,
    round(avg(case when attributed.conversion_id is not null then 1.0 else 0.0 end), 3) as coverage_rate,
    sum(conversions.value_usd)                                                  as value_usd
from conversions
left join attributed using (conversion_id)
group by 1, 2
