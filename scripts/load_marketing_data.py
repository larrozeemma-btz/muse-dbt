"""
Simulate MUSE's go-to-market data on top of the existing raw layer.

Run after `scripts/load_raw_data.py` (it reads raw.app_users and raw.subscriptions).
Two motions are modelled, as in most consumer + B2B software companies:

  * Product-led growth (PLG) — anonymous web visits with UTM parameters, a
    signup, then a paid upgrade. Exported the way a web analytics / CDP tool
    exports it: one row per session, anonymous_id before signup, user_id after.
  * Sales-led "MUSE for Business" (launched 2025) — venues, gyms and retail
    chains licensing background music. Exported from a Salesforce-like CRM:
    Lead, Account, Opportunity, Campaign, CampaignMember, with CRM column names.

Paid media spend comes from ad-platform exports (one row per campaign per day),
in USD or EUR depending on the platform account.

Journeys follow realistic patterns that make attribution models disagree:
content and organic search tend to open journeys, paid-social retargeting
tends to close them, events and webinars source enterprise pipeline.
Ingestion mess is included: inconsistent UTM casing, "(none)" vs empty values,
unmapped sources, two currencies, duplicated CRM rows.

Usage:
    python scripts/load_marketing_data.py            # uses ./muse.duckdb
"""

import argparse
from datetime import datetime, timedelta
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
SIM_END = datetime(2026, 9, 30, 23, 59, 59)
B2B_LAUNCH = datetime(2025, 1, 6)

# --------------------------------------------------------------------------- campaigns
# (campaign_code, channel, motion, ad platform or None, daily budget USD, start, end)
CAMPAIGNS = [
    ("gg_brand_search",      "paid_search",  "plg",        "google_ads", 260, "2024-01-01", None),
    ("gg_generic_search",    "paid_search",  "plg",        "google_ads", 420, "2024-03-01", None),
    ("bing_search",          "paid_search",  "plg",        "microsoft_ads", 60, "2024-06-01", None),
    ("meta_prospecting",     "paid_social",  "plg",        "meta_ads",   520, "2024-01-01", None),
    ("meta_retargeting",     "paid_social",  "plg",        "meta_ads",   310, "2024-02-01", None),
    ("tiktok_creators",      "paid_social",  "plg",        "tiktok_ads", 380, "2025-03-01", None),
    ("podcast_sponsorships", "content",      "plg",        "podcast_network", 240, "2024-05-01", None),
    ("blog_seo",             "organic_search", "plg",      None, 0, "2024-01-01", None),
    ("weekly_newsletter",    "email",        "plg",        None, 0, "2024-01-01", None),
    ("invite_a_friend",      "referral",     "plg",        None, 0, "2024-01-01", None),
    ("telco_bundle",         "partnership",  "plg",        "partner_fees", 150, "2024-09-01", None),
    ("b2b_linkedin_abm",     "paid_social",  "enterprise", "linkedin_ads", 330, "2025-01-06", None),
    ("b2b_google_search",    "paid_search",  "enterprise", "google_ads", 180, "2025-01-06", None),
    ("b2b_webinar_series",   "webinar",      "enterprise", "event_costs", 70, "2025-02-01", None),
    ("b2b_trade_shows",      "events",       "enterprise", "event_costs", 240, "2025-03-01", None),
    ("b2b_content_guides",   "content",      "enterprise", None, 0, "2025-01-06", None),
    ("b2b_partner_resellers","partnership",  "enterprise", "partner_fees", 90, "2025-04-01", None),
    ("b2b_outbound_sdr",     "outbound",     "enterprise", None, 0, "2025-01-06", None),
]

# raw UTM values per channel, as they show up in real exports (messy on purpose)
UTMS = {
    "paid_search":    [("google", "cpc"), ("Google", "CPC"), ("bing", "cpc")],
    "paid_social":    [("facebook", "paid_social"), ("instagram", "paidsocial"), ("tiktok", "cpc"), ("linkedin", "paid_social")],
    "organic_search": [("google", "organic"), ("bing", "organic"), ("duckduckgo", "organic")],
    "content":        [("podcast", "audio"), ("blog", "content"), ("youtube", "video")],
    "email":          [("newsletter", "email"), ("braze", "email ")],
    "referral":       [("invite", "referral"), ("muse_app", "share")],
    "partnership":    [("telco_partner", "partner"), ("reseller", "partner")],
    "direct":         [(None, None), ("(direct)", "(none)")],
}
PLG_FIRST_TOUCH = {"content": .22, "organic_search": .24, "paid_social": .20, "paid_search": .12,
                   "referral": .09, "partnership": .05, "direct": .06, "email": .02}
PLG_MID_TOUCH = {"email": .25, "direct": .20, "organic_search": .15, "paid_search": .15, "content": .10,
                 "paid_social": .15}
APP_CHANNEL_TO_LAST = {"paid_social": "paid_social", "app_store_search": "organic_search",
                       "referral": "referral", "partnership": "partnership", "organic": "direct"}

INDUSTRIES = ["Hospitality", "Retail", "Fitness", "Restaurants", "Offices", "Hotels"]
LEAD_SOURCES = {  # lead source → (share of leads, P(MQL), P(SQL|MQL), P(opp|SQL), P(won|opp), deal size factor)
    "Website Demo Request": (.20, .80, .62, .70, .34, 1.0),
    "Webinar":              (.16, .55, .40, .55, .26, 0.9),
    "Trade Show":           (.14, .60, .45, .60, .30, 1.6),
    "Content Download":     (.18, .30, .25, .45, .18, 0.8),
    "Paid Search":          (.10, .50, .42, .55, .24, 0.9),
    "LinkedIn Ads":         (.09, .40, .35, .50, .22, 1.1),
    "Partner Referral":     (.05, .85, .70, .75, .45, 1.3),
    "Outbound":             (.08, .35, .50, .55, .25, 1.4),
}
SOURCE_CAMPAIGN = {"Website Demo Request": "b2b_google_search", "Webinar": "b2b_webinar_series",
                   "Trade Show": "b2b_trade_shows", "Content Download": "b2b_content_guides",
                   "Paid Search": "b2b_google_search", "LinkedIn Ads": "b2b_linkedin_abm",
                   "Partner Referral": "b2b_partner_resellers", "Outbound": "b2b_outbound_sdr"}


def ts(x):
    return pd.Timestamp(x).floor("s")


def pick(rng, dist):
    keys = list(dist)
    p = np.array(list(dist.values()), dtype=float)
    return keys[rng.choice(len(keys), p=p / p.sum())]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--database", default=str(ROOT / "muse.duckdb"))
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--b2b-leads", type=int, default=4000)
    args = parser.parse_args()
    rng = np.random.default_rng(args.seed)
    con = duckdb.connect(args.database)

    users = con.execute("select user_id, signed_up_at, acquisition_channel from raw.app_users").df()
    campaign_by_code = {c[0]: c for c in CAMPAIGNS}

    # ------------------------------------------------------------ campaigns
    camp_rows = []
    for i, (code, channel, motion, platform, budget, start, end) in enumerate(CAMPAIGNS, 1):
        camp_rows.append({"Id": f"7015g{i:010d}", "Name": code.replace("_", " ").title(),
                          "utm_campaign": code, "Channel__c": channel, "Motion__c": motion,
                          "Type": "Paid" if budget else "Owned", "StartDate": pd.Timestamp(start).date(),
                          "IsActive": True})
    campaigns = pd.DataFrame(camp_rows)
    camp_id = dict(zip(campaigns["utm_campaign"], campaigns["Id"]))

    # ------------------------------------------------------------ ad spend (daily, per platform export)
    spend_rows = []
    for code, channel, motion, platform, budget, start, end in CAMPAIGNS:
        if not budget:
            continue
        days = pd.date_range(start, SIM_END.date(), freq="D")
        # budgets ramp up over time and flex by weekday / seasonality
        t = np.linspace(0, 1, len(days))
        season = 1 + 0.18 * np.sin(2 * np.pi * (days.dayofyear / 365.25 - 0.2))
        weekday = np.where(days.dayofweek >= 5, 0.8, 1.05)
        spend = budget * (0.7 + 0.6 * t) * season * weekday * rng.lognormal(0, 0.15, len(days))
        if platform == "event_costs":  # events are lumpy: a few big days
            spend = np.where(rng.random(len(days)) < 0.03, spend * 30, 0)
        currency = "EUR" if platform in ("meta_ads", "podcast_network") else "USD"
        fx = 0.92 if currency == "EUR" else 1.0
        cpc = {"paid_search": 1.6, "paid_social": 0.9, "content": 2.5}.get(channel, 3.0)
        clicks = np.maximum((spend / cpc * rng.lognormal(0, .2, len(days))).astype(int), 0)
        for d, s, c in zip(days, spend, clicks):
            if s <= 0:
                continue
            spend_rows.append({"platform": platform, "date": d.date(), "campaign": code,
                               "spend": round(s * fx, 2), "currency": currency,
                               "impressions": int(c * rng.uniform(35, 90)), "clicks": int(c)})
    ad_spend = pd.DataFrame(spend_rows)

    # ------------------------------------------------------------ PLG web sessions
    sess = []
    sid = 0

    def add_session(anon, uid, when, channel, campaign=None):
        nonlocal sid
        sid += 1
        src, med = UTMS[channel][rng.integers(len(UTMS[channel]))]
        if campaign is None:
            options = [c[0] for c in CAMPAIGNS if c[1] == channel and c[2] == "plg" and pd.Timestamp(c[5]) <= when]
            campaign = options[rng.integers(len(options))] if options and channel != "direct" else None
        if rng.random() < 0.01:                       # sources nobody mapped yet
            src, med = ("chatgpt.com", "referral") if rng.random() < .6 else ("perplexity", "(not set)")
        sess.append({
            "session_id": f"s_{sid:08d}", "anonymous_id": anon, "user_id": uid,
            "session_started_at": when.strftime("%Y-%m-%dT%H:%M:%S.000Z"),
            "utm_source": src, "utm_medium": med, "utm_campaign": campaign if src else None,
            "landing_page": rng.choice(["/", "/pricing", "/download", "/blog", "/business"]),
            "device_type": rng.choice(["mobile", "desktop", "tablet"], p=[.62, .33, .05]),
        })

    for u in users.itertuples():
        signup = pd.Timestamp(u.signed_up_at)
        anon = f"a_{rng.integers(1e12):012d}"
        n_touch = 1 + rng.poisson(1.7)
        start = signup - timedelta(days=float(rng.uniform(0, 28)))
        times = sorted([start + (signup - start) * float(f) for f in rng.uniform(0, 1, n_touch - 1)])
        chans = [pick(rng, PLG_FIRST_TOUCH)] + [pick(rng, PLG_MID_TOUCH) for _ in range(n_touch - 2)]
        for when, ch in zip([start] + times[1:], chans):
            add_session(anon, None, when, ch)
        # paid-social retargeting loves to show up right before conversion
        if rng.random() < 0.35 and signup > pd.Timestamp("2024-02-01"):
            add_session(anon, None, signup - timedelta(minutes=float(rng.uniform(5, 600))), "paid_social", "meta_retargeting")
        # the signup session itself carries both ids → identity stitching
        add_session(anon, u.user_id, signup - timedelta(seconds=40), APP_CHANNEL_TO_LAST[u.acquisition_channel])
        # a few post-signup visits
        for _ in range(rng.poisson(1.2)):
            later = signup + timedelta(days=float(rng.uniform(1, 120)))
            if later < SIM_END:
                add_session(anon, u.user_id, later, pick(rng, {"direct": .6, "email": .3, "organic_search": .1}))

    # visitors who never sign up (the top of the funnel)
    for _ in range(len(users) * 3):
        anon = f"a_{rng.integers(1e12):012d}"
        first = pd.Timestamp("2024-01-01") + timedelta(seconds=float(rng.uniform(0, (SIM_END - datetime(2024, 1, 1)).total_seconds())))
        add_session(anon, None, first, pick(rng, PLG_FIRST_TOUCH))
        for _ in range(rng.poisson(0.6)):
            later = first + timedelta(days=float(rng.uniform(0, 20)))
            if later < SIM_END:
                add_session(anon, None, later, pick(rng, PLG_MID_TOUCH))
    sessions = pd.DataFrame(sess)
    sessions["utm_source"] = sessions["utm_source"].where(rng.random(len(sessions)) > 0.03, "")  # blank vs null

    # ------------------------------------------------------------ B2B: accounts, leads, opportunities
    accounts, leads, opps, members = [], [], [], []
    acc_ids = []
    for i in range(int(args.b2b_leads * 0.35)):
        aid = f"0015g{i:010d}"
        acc_ids.append(aid)
        accounts.append({"Id": aid, "Name": f"{rng.choice(['Blue', 'North', 'Urban', 'Golden', 'Prime', 'Velvet', 'Coastal'])} "
                                            f"{rng.choice(['Fitness', 'Coffee', 'Hotels', 'Retail', 'Bistro', 'Studios', 'Spa'])} {i}",
                         "Industry": rng.choice(INDUSTRIES), "NumberOfEmployees": int(rng.lognormal(4, 1.2)),
                         "BillingCountry": rng.choice(["US", "FR", "GB", "DE", "ES", "CA"], p=[.4, .2, .15, .1, .08, .07]),
                         "CreatedDate": None})
    b2b_days = (SIM_END - B2B_LAUNCH).days
    src_names = list(LEAD_SOURCES)
    src_p = np.array([LEAD_SOURCES[s][0] for s in src_names])
    opp_seq = mem_seq = 0
    for i in range(args.b2b_leads):
        source = src_names[rng.choice(len(src_names), p=src_p / src_p.sum())]
        share, p_mql, p_sql, p_opp, p_won, size = LEAD_SOURCES[source]
        # lead volume grows as the business motion matures
        created = B2B_LAUNCH + timedelta(days=float(b2b_days * np.sqrt(rng.random())), hours=float(rng.uniform(8, 18)))
        acc = acc_ids[rng.integers(len(acc_ids))]
        lead_id = f"00Q5g{i:010d}"
        mql = created + timedelta(days=float(rng.exponential(4))) if rng.random() < p_mql else None
        sql = mql + timedelta(days=float(rng.exponential(6))) if mql is not None and rng.random() < p_sql else None
        opp_id, opp_created = None, None
        candidate_opp_at = sql + timedelta(days=float(rng.exponential(5))) if sql is not None else None
        if candidate_opp_at is not None and candidate_opp_at < SIM_END and rng.random() < p_opp:
            opp_seq += 1
            opp_id = f"0065g{opp_seq:010d}"
            opp_created = candidate_opp_at
            seats = max(1, int(rng.lognormal(1.6, 0.9)))
            amount = round(seats * 1188 * size * rng.uniform(.8, 1.25), -1)  # annual contract, $99/location/month
            cycle = rng.gamma(3, 18)
            close = opp_created + timedelta(days=float(cycle))
            closed = close < SIM_END
            won = closed and rng.random() < p_won
            stage = ("Closed Won" if won else "Closed Lost") if closed else rng.choice(
                ["Discovery", "Demo", "Proposal", "Negotiation"], p=[.35, .3, .2, .15])
            opps.append({"Id": opp_id, "AccountId": acc, "Name": f"{acc} - New Business", "Type": "New Business",
                         "StageName": stage, "Amount": float(amount), "CreatedDate": ts(opp_created),
                         "CloseDate": close.date(), "IsClosed": bool(closed), "IsWon": bool(won),
                         "LeadSource": source})
        status = ("Converted" if opp_id else "Qualified" if sql is not None else "Working" if mql is not None
                  else rng.choice(["Open", "Nurture", "Disqualified"], p=[.3, .45, .25]))
        if created > SIM_END:
            continue
        leads.append({"Id": lead_id, "Email": f"buyer{i}@{acc.lower()}.example.com", "Company": acc,
                      "LeadSource": source if rng.random() > .02 else source.upper(),
                      "Status": status, "CreatedDate": ts(created),
                      "MQL_Date__c": ts(mql) if mql is not None and mql < SIM_END else None,
                      "SQL_Date__c": ts(sql) if sql is not None and sql < SIM_END else None,
                      "IsConverted": opp_id is not None, "ConvertedAccountId": acc if opp_id else None,
                      "ConvertedOpportunityId": opp_id})
        # campaign touches: the sourcing campaign, then nurture touches until the opportunity is created
        horizon = opp_created or min(created + timedelta(days=120), SIM_END)
        touches = [(SOURCE_CAMPAIGN[source], created)]
        for _ in range(rng.poisson(1.6 if opp_id else 0.8)):
            when = created + (horizon - created) * float(rng.uniform(0.05, 0.98))
            camp = pick(rng, {"b2b_webinar_series": .3, "b2b_content_guides": .25, "b2b_linkedin_abm": .25,
                              "b2b_trade_shows": .1, "b2b_google_search": .1})
            touches.append((camp, when))
        for camp, when in touches:
            mem_seq += 1
            members.append({"Id": f"00v5g{mem_seq:010d}", "CampaignId": camp_id[camp], "LeadId": lead_id,
                            "Status": "Responded", "HasResponded": True, "FirstRespondedDate": when.date(),
                            "CreatedDate": ts(when)})

    accounts = pd.DataFrame(accounts)
    first_lead = pd.DataFrame(leads).groupby("Company")["CreatedDate"].min()
    accounts["CreatedDate"] = accounts["Id"].map(first_lead)
    accounts = accounts.dropna(subset=["CreatedDate"])
    opps = pd.DataFrame(opps)
    leads = pd.DataFrame(leads)
    leads = pd.concat([leads, leads.sample(frac=0.005, random_state=args.seed)], ignore_index=True)  # CRM sync dupes
    members = pd.DataFrame(members)

    con.execute("create schema if not exists raw")
    for name, df in (("marketing_campaigns", campaigns), ("ad_platform_spend", ad_spend),
                     ("web_sessions", sessions), ("crm_accounts", accounts), ("crm_leads", leads),
                     ("crm_opportunities", opps), ("crm_campaign_members", members)):
        con.register("df_view", df)
        con.execute(f"create or replace table raw.{name} as select * from df_view")
        con.unregister("df_view")
        print(f"raw.{name:<24} {len(df):>9,} rows")
    con.close()


if __name__ == "__main__":
    main()
