-- A funnel stage can never hold more people than the stage before it.
select 'plg' as funnel, cast(month_start as {{ dbt.type_string() }}) as cohort, first_touch_channel as segment
from {{ ref('rpt_plg_funnel') }}
where signups > visitors or activated_users > signups or paid_within_90d > activated_users
union all
select 'enterprise', cast(month_start as {{ dbt.type_string() }}), lead_source
from {{ ref('rpt_enterprise_funnel') }}
where mqls > leads or sqls > mqls or opportunities > sqls or won_deals > opportunities
