{#
    Classic monthly retention triangle: of the listeners who signed up in
    month M, what share streamed at least once in month M+k?
#}

with users as (

    select user_id, signup_cohort_month from {{ ref('dim_users') }}

),

activity as (

    select distinct user_id, {{ month_start('event_date') }} as activity_month
    from {{ ref('fct_listening_events') }}
    where is_stream

),

cohort_sizes as (

    select signup_cohort_month, count(*) as cohort_size
    from users
    group by 1

),

retained as (

    select
        users.signup_cohort_month,
        {{ dbt.datediff('users.signup_cohort_month', 'activity.activity_month', 'month') }} as months_since_signup,
        count(distinct users.user_id) as active_users
    from users
    inner join activity using (user_id)
    group by 1, 2

)

select
    retained.signup_cohort_month,
    retained.months_since_signup,
    cohort_sizes.cohort_size,
    retained.active_users,
    round(retained.active_users / cohort_sizes.cohort_size, 3) as retention_rate
from retained
inner join cohort_sizes using (signup_cohort_month)
where retained.months_since_signup >= 0
