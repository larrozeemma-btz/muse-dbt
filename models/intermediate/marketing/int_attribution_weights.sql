{{ config(materialized='table') }}

{#
    Multi-touch attribution. For each conversion, the touches by the same person
    inside the lookback window (30 days PLG, 365 days enterprise — vars) share
    the credit. Five models are computed side by side so their trade-offs are
    visible instead of argued about:

      first_touch      100 % to the touch that opened the journey
      last_touch       100 % to the touch right before converting
      linear           equal split
      position_based   40 % first, 40 % last, 20 % spread over the middle (U-shape)
      time_decay       weight halves every `muse_time_decay_half_life_days` before conversion

    Every model's weights sum to 1 per conversion (singular test).
#}

with conversions as (

    select * from {{ ref('int_marketing_conversions') }}

),

touchpoints as (

    select * from {{ ref('int_marketing_touchpoints') }}

),

eligible as (

    select
        conversions.conversion_id,
        conversions.conversion_type,
        conversions.motion,
        conversions.converted_at,
        conversions.value_usd,
        touchpoints.touchpoint_id,
        touchpoints.touched_at,
        touchpoints.channel,
        touchpoints.campaign_code,
        {{ dbt.datediff('touchpoints.touched_at', 'conversions.converted_at', 'second') }} / 86400.0 as days_before_conversion
    from conversions
    inner join touchpoints
        on  touchpoints.person_key = conversions.person_key
        and touchpoints.motion     = conversions.motion
        and touchpoints.touched_at <= conversions.converted_at
        and touchpoints.touched_at >= {{ timestamp_add_days(
                'conversions.converted_at',
                '-1 * case conversions.motion when \'plg\' then ' ~ var('muse_plg_lookback_days')
                    ~ ' else ' ~ var('muse_enterprise_lookback_days') ~ ' end') }}

),

positioned as (

    select
        *,
        count(*) over (partition by conversion_id)                                          as n_touches,
        row_number() over (partition by conversion_id order by touched_at, touchpoint_id)   as touch_position,
        pow(0.5, days_before_conversion / {{ var('muse_time_decay_half_life_days') }})       as decay_raw
    from eligible

)

select
    conversion_id,
    conversion_type,
    motion,
    converted_at,
    value_usd,
    touchpoint_id,
    touched_at,
    channel,
    campaign_code,
    round(days_before_conversion, 2)                                        as days_before_conversion,
    n_touches,
    touch_position,
    case when touch_position = 1 then 1.0 else 0.0 end                      as weight_first_touch,
    case when touch_position = n_touches then 1.0 else 0.0 end              as weight_last_touch,
    1.0 / n_touches                                                         as weight_linear,
    case
        when n_touches = 1 then 1.0
        when n_touches = 2 then 0.5
        when touch_position = 1 or touch_position = n_touches then 0.4
        else 0.2 / (n_touches - 2)
    end                                                                     as weight_position_based,
    decay_raw / sum(decay_raw) over (partition by conversion_id)            as weight_time_decay
from positioned
