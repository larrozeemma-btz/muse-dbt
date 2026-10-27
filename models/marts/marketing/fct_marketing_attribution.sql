{#
    Long format: one row per conversion × touchpoint × attribution model,
    with the credit (share of the conversion) and the credited value.
    Long beats wide here: dashboards filter on `attribution_model` instead of
    picking among five columns, and adding a sixth model is one more union.
#}

{% set models = ['first_touch', 'last_touch', 'linear', 'position_based', 'time_decay'] %}

with weights as (

    select * from {{ ref('int_attribution_weights') }}

)

{% for m in models %}
select
    conversion_id,
    conversion_type,
    motion,
    converted_at,
    {{ month_start('converted_at') }}       as conversion_month,
    touchpoint_id,
    touched_at,
    channel,
    campaign_code,
    n_touches,
    touch_position,
    '{{ m }}'                               as attribution_model,
    weight_{{ m }}                          as credit,
    weight_{{ m }} * value_usd              as credited_value_usd
from weights
where weight_{{ m }} > 0
{% if not loop.last %}union all{% endif %}
{% endfor %}
