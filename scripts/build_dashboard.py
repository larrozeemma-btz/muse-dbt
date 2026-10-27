"""
Build the static marketing dashboard (docs/index.html) from the dbt marts.

Reads the `marketing` schema of the local DuckDB warehouse, embeds the results
as JSON and renders them with Chart.js. The page is served by GitHub Pages, so
the dashboard is viewable without any BI tool or login.

    dbt build --profiles-dir . && python scripts/build_dashboard.py
"""

import json
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "index.html"

QUERIES = {
    "weekly": """
        select cast(week_start as varchar) as week, round(spend_usd) as spend, round(plg_spend_usd) as plg_spend,
               round(enterprise_spend_usd) as ent_spend, signups, paid_conversions,
               blended_cac_usd as cac, new_leads, new_mqls, pipeline_created_usd as pipeline, closed_won_usd as won
        from marketing.rpt_weekly_marketing_review
        where week_start >= (select max(week_start) from marketing.rpt_weekly_marketing_review) - interval 51 week
        order by week_start""",
    "attribution": """
        select channel, attribution_model as model, round(100 * sum(credit) / sum(sum(credit)) over (partition by attribution_model), 1) as share
        from marketing.fct_marketing_attribution
        where conversion_type = 'plg_signup'
          and conversion_month >= (select max(month_start) from marketing.rpt_plg_funnel) - interval 11 month
        group by 1, 2""",
    "cost_per_signup": """
        with c as (
            select channel, attribution_model as model, sum(credit) as credited
            from marketing.fct_marketing_attribution
            where conversion_type = 'plg_signup'
              and conversion_month >= (select max(month_start) from marketing.rpt_plg_funnel) - interval 11 month
            group by 1, 2),
        s as (
            select channel, sum(spend_usd) as spend
            from marketing.fct_ad_spend
            where motion = 'plg' and spend_month >= (select max(month_start) from marketing.rpt_plg_funnel) - interval 11 month
            group by 1)
        select channel, model, round(spend / credited) as cost
        from c join s using (channel)""",
    "plg_funnel": """
        select first_touch_channel as channel, sum(visitors) as visitors, sum(signups) as signups,
               sum(activated_users) as activated, sum(paid_within_90d) as paid,
               sum(paid_without_activation) as paid_no_activation
        from marketing.rpt_plg_funnel
        where month_start >= (select max(month_start) from marketing.rpt_plg_funnel) - interval 14 month
          and month_start <= (select max(month_start) from marketing.rpt_plg_funnel) - interval 3 month
        group by 1 order by signups desc""",
    "enterprise": """
        select lead_source as source, sum(leads) as leads, sum(mqls) as mqls, sum(sqls) as sqls,
               sum(opportunities) as opps, sum(won_deals) as won, round(sum(won_usd)) as won_usd,
               round(sum(won_usd) / sum(leads)) as won_per_lead,
               round(sum(won_deals) / nullif(sum(opportunities), 0), 3) as win_rate
        from marketing.rpt_enterprise_funnel group by 1 order by won_per_lead desc""",
    "pipeline": """
        with s as (select channel, sum(spend_usd) as spend from marketing.fct_ad_spend where motion = 'enterprise' group by 1)
        select channel, round(sum(sourced_pipeline_usd)) as sourced, round(sum(influenced_pipeline_usd)) as influenced,
               round(max(s.spend)) as spend
        from marketing.rpt_marketing_pipeline left join s using (channel)
        group by 1 order by sourced desc""",
    "coverage": """
        select conversion_type, sum(conversions) as conversions,
               round(sum(attributable_conversions) / sum(conversions), 3) as coverage
        from marketing.rpt_attribution_coverage group by 1 order by 1""",
}

TEMPLATE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>MUSE Marketing Review</title>
<meta name="description" content="Weekly marketing measurement dashboard built from the MUSE dbt project">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.1/dist/chart.umd.min.js"></script>
<style>
:root {
  --bg: #f7f7f5; --surface: #ffffff; --text: #1d1d1b; --muted: #6b6b66; --border: #e6e4df;
  --accent: #c2571a; --c1: #c2571a; --c2: #2f6f8f; --c3: #6b8f3a; --c4: #8a5a9b; --c5: #b8892e;
  --good: #2e7d4f; --bad: #b3261e;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
    --bg: #161614; --surface: #20201d; --text: #ecebe7; --muted: #a3a29c; --border: #34332f;
    --accent: #e0793c; --c1: #e0793c; --c2: #5ba3c7; --c3: #94bd5e; --c4: #b48bc4; --c5: #d9b25a;
    --good: #5cbf85; --bad: #ef7b72;
  }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--text); font: 15px/1.5 Inter, system-ui, sans-serif; }
main { max-width: 1180px; margin: 0 auto; padding: 32px 16px 64px; }
header h1 { margin: 0; font-size: 28px; letter-spacing: -0.02em; }
header p { margin: 6px 0 0; color: var(--muted); }
header a { color: var(--accent); }
.tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); gap: 12px; margin: 24px 0; }
.tile { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 14px 16px; }
.tile .label { color: var(--muted); font-size: 13px; }
.tile .value { font-size: 24px; font-weight: 700; margin-top: 2px; font-variant-numeric: tabular-nums; }
.tile .delta { font-size: 13px; font-weight: 600; }
.up { color: var(--good); } .down { color: var(--bad); }
section { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 20px; margin-top: 16px; }
section h2 { margin: 0; font-size: 18px; }
section .sub { margin: 4px 0 14px; color: var(--muted); font-size: 14px; }
.grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
@media (max-width: 860px) { .grid2 { grid-template-columns: 1fr; } }
.chart { position: relative; height: 320px; }
.seg { display: inline-flex; border: 1px solid var(--border); border-radius: 8px; overflow: hidden; margin-bottom: 12px; flex-wrap: wrap; }
.seg button { border: 0; background: transparent; color: var(--text); padding: 6px 12px; font: inherit; font-size: 13px; cursor: pointer; }
.seg button.on { background: var(--accent); color: #fff; }
.tablewrap { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; font-size: 14px; font-variant-numeric: tabular-nums; }
th, td { text-align: right; padding: 8px 10px; border-bottom: 1px solid var(--border); white-space: nowrap; }
th:first-child, td:first-child { text-align: left; }
th { color: var(--muted); font-weight: 500; }
.note { color: var(--muted); font-size: 13px; margin-top: 10px; }
footer { color: var(--muted); font-size: 13px; margin-top: 28px; }
</style>
</head>
<body>
<main>
<header>
  <h1>MUSE · Weekly marketing review</h1>
  <p>Data through week of <b id="lastweek"></b> · built from the <a href="https://github.com/larrozeemma-btz/muse-dbt">muse-dbt</a> marts ·
     definitions in the <a href="https://github.com/larrozeemma-btz/muse-dbt/blob/main/docs/metrics_glossary.md">metrics glossary</a> ·
     findings in the <a href="https://github.com/larrozeemma-btz/muse-dbt/blob/main/docs/insights_memo.md">insights memo</a> · simulated data</p>
</header>

<div class="tiles" id="tiles"></div>

<section>
  <h2>Consumer spend, signups and CAC</h2>
  <p class="sub">Weekly, last 52 weeks, product-led motion only. CAC = consumer paid media ÷ paid conversions (media CAC, not fully loaded).</p>
  <div class="chart"><canvas id="weeklyChart"></canvas></div>
</section>

<section>
  <h2>Attribution: who gets credit for signups?</h2>
  <p class="sub">Share of signup credit by channel, last 12 months. Switch models to see how the story changes.</p>
  <div class="seg" id="modelSeg"></div>
  <div class="grid2">
    <div class="chart"><canvas id="attrChart"></canvas></div>
    <div class="tablewrap"><table id="costTable"></table>
      <p class="note" id="costNote">Cost per credited signup for paid channels.</p></div>
  </div>
</section>

<div class="grid2">
  <section>
    <h2>Product-led funnel</h2>
    <p class="sub">By first-touch channel, cohorts with ≥ 3 months to mature. Each rate is from the previous stage.</p>
    <div class="tablewrap"><table id="plgTable"></table></div>
    <p class="note" id="plgNote"></p>
  </section>
  <section>
    <h2>Attribution coverage</h2>
    <p class="sub">Share of outcomes with at least one marketing touch in the lookback window.</p>
    <div class="tablewrap"><table id="covTable"></table></div>
    <p class="note">Paid upgrades often happen weeks after the last marketing touch. Attribute signups, and treat the upgrade as a product metric.</p>
  </section>
</div>

<section>
  <h2>MUSE for Business: lead funnel by source</h2>
  <p class="sub">All cohorts since launch (Jan 2025). Sorted by bookings per lead.</p>
  <div class="tablewrap"><table id="entTable"></table></div>
</section>

<section>
  <h2>Sourced vs influenced pipeline</h2>
  <p class="sub">Sourced = first-touch credit (adds to 100 %). Influenced = full amount for every channel that touched the deal (adds to &gt; 100 %).</p>
  <div class="chart"><canvas id="pipeChart"></canvas></div>
</section>

<footer>Generated by <code>scripts/build_dashboard.py</code> from dbt models · MUSE is a portfolio project, all go-to-market data is simulated.</footer>
</main>

<script>
const D = __DATA__;
const css = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const palette = ['--c1','--c2','--c3','--c4','--c5'].map(css);
const usd = v => v == null ? '–' : '$' + Math.round(v).toLocaleString('en-US');
const usdk = v => v == null ? '–' : (Math.abs(v) >= 1e6 ? '$' + (v/1e6).toFixed(2) + 'M' : '$' + Math.round(v/1000) + 'k');
const pct = v => v == null ? '–' : (v*100).toFixed(1) + '%';
const num = v => v == null ? '–' : Math.round(v).toLocaleString('en-US');
Chart.defaults.font.family = 'Inter, system-ui, sans-serif';
Chart.defaults.color = css('--muted');
Chart.defaults.borderColor = css('--border');

// ---- tiles: last 13 weeks vs previous 13
const w = D.weekly; document.getElementById('lastweek').textContent = w[w.length-1].week;
const sum = (a, k) => a.reduce((s, r) => s + (r[k] || 0), 0);
const cur = w.slice(-13), prev = w.slice(-26, -13);
const tiles = [
  ['Marketing spend', sum(cur,'spend'), sum(prev,'spend'), usdk, false],
  ['Signups', sum(cur,'signups'), sum(prev,'signups'), num, false],
  ['Paid conversions', sum(cur,'paid_conversions'), sum(prev,'paid_conversions'), num, false],
  ['Consumer CAC', sum(cur,'plg_spend')/sum(cur,'paid_conversions'), sum(prev,'plg_spend')/sum(prev,'paid_conversions'), usd, true],
  ['New leads', sum(cur,'new_leads'), sum(prev,'new_leads'), num, false],
  ['Pipeline created', sum(cur,'pipeline'), sum(prev,'pipeline'), usdk, false],
  ['Pipeline per B2B $', sum(cur,'pipeline')/sum(cur,'ent_spend'), sum(prev,'pipeline')/sum(prev,'ent_spend'), v => '$' + v.toFixed(1), false],
  ['Closed-won', sum(cur,'won'), sum(prev,'won'), usdk, false],
];
document.getElementById('tiles').innerHTML = tiles.map(([l, c, p, f, lowerIsBetter]) => {
  const d = (c - p) / p, good = lowerIsBetter ? d < 0 : d > 0;
  return `<div class="tile"><div class="label">${l} · 13 wk</div><div class="value">${f(c)}</div>
          <div class="delta ${good ? 'up' : 'down'}">${d > 0 ? '▲' : '▼'} ${Math.abs(d*100).toFixed(1)}% vs prior 13 wk</div></div>`;
}).join('');

// ---- weekly chart
new Chart(document.getElementById('weeklyChart'), {
  data: { labels: w.map(r => r.week), datasets: [
    { type: 'bar', label: 'Consumer spend (USD)', data: w.map(r => r.plg_spend), backgroundColor: palette[1] + '99', yAxisID: 'y' },
    { type: 'line', label: 'Signups', data: w.map(r => r.signups), borderColor: palette[0], backgroundColor: palette[0], yAxisID: 'y1', tension: .3, pointRadius: 0 },
    { type: 'line', label: 'Consumer CAC (USD)', data: w.map(r => r.cac), borderColor: palette[3], backgroundColor: palette[3], yAxisID: 'y2', tension: .3, pointRadius: 0, borderDash: [4,3] },
  ]},
  options: { maintainAspectRatio: false, interaction: { mode: 'index', intersect: false },
    scales: { x: { ticks: { maxTicksLimit: 12 } }, y: { position: 'left', title: { display: true, text: 'Spend' } },
              y1: { position: 'right', grid: { drawOnChartArea: false }, title: { display: true, text: 'Signups' } },
              y2: { display: false } } }
});

// ---- attribution
const models = ['first_touch','last_touch','linear','position_based','time_decay'];
const label = m => m.replace('_', ' ').replace(/^./, c => c.toUpperCase());
const channels = [...new Set(D.attribution.map(r => r.channel))].filter(c => c !== 'unmapped');
let model = 'position_based';
const attrChart = new Chart(document.getElementById('attrChart'), {
  type: 'bar', data: { labels: channels, datasets: [{ label: 'Share of signup credit (%)', data: [], backgroundColor: palette[0] }] },
  options: { indexAxis: 'y', maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { x: { max: 40, ticks: { callback: v => v + '%' } } } }
});
function drawAttr() {
  const byCh = Object.fromEntries(D.attribution.filter(r => r.model === model).map(r => [r.channel, r.share]));
  attrChart.data.datasets[0].data = channels.map(c => byCh[c] || 0); attrChart.update();
  document.querySelectorAll('#modelSeg button').forEach(b => b.classList.toggle('on', b.dataset.m === model));
}
document.getElementById('modelSeg').innerHTML = models.map(m => `<button data-m="${m}">${label(m)}</button>`).join('');
document.querySelectorAll('#modelSeg button').forEach(b => b.onclick = () => { model = b.dataset.m; drawAttr(); });
drawAttr();
const paid = [...new Set(D.cost_per_signup.map(r => r.channel))];
const cost = (c, m) => (D.cost_per_signup.find(r => r.channel === c && r.model === m) || {}).cost;
document.getElementById('costTable').innerHTML = '<tr><th>Paid channel</th>' + models.map(m => `<th>${label(m)}</th>`).join('') + '</tr>' +
  paid.map(c => `<tr><td>${c.replace('_', ' ')}</td>` + models.map(m => `<td>${usd(cost(c, m))}</td>`).join('') + '</tr>').join('');

const ratio = cost('paid_search', 'last_touch') / cost('paid_search', 'first_touch');
if (ratio) document.getElementById('costNote').textContent +=
  ` Under last touch, paid search looks ${Math.round(ratio)}× more expensive than under first touch.`;

// ---- tables
const t = (id, head, rows) => document.getElementById(id).innerHTML =
  '<tr>' + head.map(h => `<th>${h}</th>`).join('') + '</tr>' + rows.map(r => '<tr>' + r.map(c => `<td>${c}</td>`).join('') + '</tr>').join('');
t('plgTable', ['First touch', 'Visitors', 'Visit→signup', 'Signup→activated', 'Activated→paid ≤ 90d'],
  D.plg_funnel.map(r => [r.channel.replace('_', ' '), num(r.visitors), pct(r.signups / r.visitors), pct(r.activated / r.signups), pct(r.paid / r.activated)]));
const noAct = sum(D.plg_funnel, 'paid_no_activation'), allPaid = noAct + sum(D.plg_funnel, 'paid');
document.getElementById('plgNote').textContent =
  `Strict funnel: only activated users count as the paid step. ${num(noAct)} of ${num(allPaid)} payers (${pct(noAct / allPaid)}) paid without activating and are tracked separately.`;
t('covTable', ['Outcome', 'Count', 'Coverage'], D.coverage.map(r => [r.conversion_type.replace('_', ' '), num(r.conversions), pct(r.coverage)]));
t('entTable', ['Lead source', 'Leads', 'MQLs', 'SQLs', 'Opps', 'Won', 'Win rate', 'Bookings', 'Bookings / lead'],
  D.enterprise.map(r => [r.source, num(r.leads), num(r.mqls), num(r.sqls), num(r.opps), num(r.won), pct(r.win_rate), usdk(r.won_usd), usd(r.won_per_lead)]));

// ---- pipeline chart
const p = D.pipeline;
new Chart(document.getElementById('pipeChart'), {
  type: 'bar', data: { labels: p.map(r => r.channel.replace('_', ' ')), datasets: [
    { label: 'Sourced pipeline', data: p.map(r => r.sourced), backgroundColor: palette[1] },
    { label: 'Influenced pipeline', data: p.map(r => r.influenced), backgroundColor: palette[0] + 'aa' },
  ]},
  options: { maintainAspectRatio: false, scales: { y: { ticks: { callback: v => usdk(v) } } },
    plugins: { tooltip: { callbacks: { afterBody: items => { const r = p[items[0].dataIndex]; return r.spend ? 'Spend: ' + usdk(r.spend) : 'No paid spend'; } } } } }
});
</script>
</body>
</html>
"""


def main():
    con = duckdb.connect(str(ROOT / "muse.duckdb"), read_only=True)
    data = {}
    for key, sql in QUERIES.items():
        df = con.execute(sql).df()
        data[key] = json.loads(df.to_json(orient="records", date_format="iso"))
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(TEMPLATE.replace("__DATA__", json.dumps(data)))
    print(f"wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
