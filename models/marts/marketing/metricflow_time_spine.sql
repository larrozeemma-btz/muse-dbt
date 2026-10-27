-- Daily spine MetricFlow uses to fill gaps and compute cumulative metrics.
select date_day from {{ ref('dim_date') }}
