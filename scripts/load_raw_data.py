"""
Build the MUSE raw layer in DuckDB.

1. **Real catalog** — downloads the public Spotify Tracks Dataset
   (114k rows, 125 genres, audio features; BSD licence) from Hugging Face and
   loads it untouched into `raw.spotify_tracks`.
2. **Simulated product data** — listening behaviour is never published, so
   users, onboarding answers, subscriptions and millions of listening events
   are simulated *on top of the real catalog* with realistic dynamics:
     - user growth over time, churn, heavy-tailed activity levels
     - daily / weekly seasonality (commute & evening peaks, weekend lie-ins)
     - sessions of consecutive tracks, popularity power law, heavy rotation
     - skips, likes, playlist adds, replays depending on taste fit
     - freemium funnel: free → premium upgrades, cancellations, plan changes
3. **Ingestion noise** — the kind of mess real pipelines receive: duplicate
   deliveries, mixed timestamp formats, inconsistent casing, logged-out events,
   orphan track ids and late-arriving events (`ingested_at` ≫ `event_at`).

Usage:
    python scripts/load_raw_data.py                 # 10k users (~4M events)
    python scripts/load_raw_data.py --users 50000   # ~20M events, needs a roomier machine
    python scripts/load_raw_data.py --users 2000    # quick / CI run
"""

import argparse
import time
import urllib.request
from datetime import datetime
from pathlib import Path

import duckdb
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
CATALOG_URL = (
    "https://huggingface.co/datasets/maharshipandya/spotify-tracks-dataset/"
    "resolve/main/dataset.csv"
)
CATALOG_PATH = ROOT / "data" / "raw" / "spotify_tracks.csv"

SIM_START = datetime(2024, 1, 1)
SIM_END = datetime(2026, 9, 30, 23, 59, 59)
MUSE_RECO_LAUNCH = datetime(2025, 6, 1)  # in-app recommendations go live

COUNTRIES = ["FR", "US", "GB", "DE", "ES", "BR", "MX", "CA", "IT", "BE", "SE", "JP", "IN", "AU"]
COUNTRY_W = [18, 20, 9, 8, 6, 8, 5, 4, 5, 3, 2, 4, 5, 3]
PLANS = {"free": 0.0, "premium": 10.99, "student": 5.99, "family": 17.99}
PLAN_W = [0.993, 0.005, 0.0015, 0.0005]  # nearly everyone starts free
DEVICES = ["mobile", "desktop", "web", "smart_speaker", "tv"]
DEVICE_W = [0.65, 0.18, 0.09, 0.05, 0.03]
CHANNELS = ["organic", "paid_social", "referral", "app_store_search", "partnership"]
CHANNEL_W = [0.38, 0.24, 0.16, 0.15, 0.07]
CONTEXTS = ["playlist", "album", "artist", "search", "radio", "muse_recommendation"]

# listening intensity by hour of day (local time) — commute + evening peaks
HOUR_W = np.array([2, 1, .6, .4, .4, .8, 2.5, 5, 7, 6, 5, 5, 6, 5.5, 5, 5, 6, 7.5, 8, 8, 7.5, 6.5, 5, 3.5])
HOUR_W = HOUR_W / HOUR_W.sum()
WEEKEND_HOUR_W = np.array([3.5, 2.5, 1.5, .8, .5, .4, .6, 1.2, 2.5, 4, 5.5, 6.5, 7, 7, 7, 6.5, 6.5, 6.5, 7, 7, 7, 6.5, 5.5, 4.5])
WEEKEND_HOUR_W = WEEKEND_HOUR_W / WEEKEND_HOUR_W.sum()


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def download_catalog():
    if CATALOG_PATH.exists():
        log(f"catalog already downloaded: {CATALOG_PATH.relative_to(ROOT)}")
        return
    CATALOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    log(f"downloading Spotify Tracks Dataset → {CATALOG_PATH.relative_to(ROOT)}")
    urllib.request.urlretrieve(CATALOG_URL, CATALOG_PATH)


def to_ts(seconds):
    """Seconds since SIM_START → numpy datetime64[s]."""
    return np.datetime64(SIM_START, "s") + seconds.astype("timedelta64[s]")


def simulate(con, n_users, seed):
    rng = np.random.default_rng(seed)
    horizon = int((SIM_END - SIM_START).total_seconds())
    reco_launch = int((MUSE_RECO_LAUNCH - SIM_START).total_seconds())

    # ------------------------------------------------------------------ catalog
    cat = con.execute("""
        select track_id, any_value(track_genre) as genre, max(popularity) as popularity,
               max(duration_ms) as duration_ms
        from raw.spotify_tracks
        where track_id is not null and artists is not null
        group by track_id
    """).df()
    genres = np.array(sorted(cat["genre"].unique()))
    genre_idx = {g: i for i, g in enumerate(genres)}
    cat["g"] = cat["genre"].map(genre_idx)
    track_ids = cat["track_id"].to_numpy()
    durations = cat["duration_ms"].to_numpy()
    pops = cat["popularity"].to_numpy()

    families = pd.read_csv(ROOT / "seeds" / "genre_families.csv").set_index("genre_name")["genre_family"]
    genre_family = np.array([families.get(g, "Other") for g in genres])

    # within a genre, track choice follows a popularity power law
    genre_tracks, genre_probs = [], []
    for gi in range(len(genres)):
        idx = np.flatnonzero(cat["g"].to_numpy() == gi)
        w = np.exp(pops[idx] / 12.0)
        genre_tracks.append(idx)
        genre_probs.append(w / w.sum())
    # global genre appeal (pop / hip-hop / latin are mainstream, grindcore isn't)
    genre_appeal = np.array([np.exp(pops[t].mean() / 15.0) for t in genre_tracks])
    genre_appeal /= genre_appeal.sum()

    # -------------------------------------------------------------------- users
    log(f"simulating {n_users:,} users")
    signup_s = (np.sqrt(rng.random(n_users)) * (horizon - 15 * 86400)).astype(np.int64)  # growth curve
    churns = rng.random(n_users) < 0.42
    lifetime_s = np.where(churns, rng.exponential(110 * 86400, n_users), horizon).astype(np.int64)
    last_active_s = np.minimum(signup_s + lifetime_s, horizon)
    sessions_per_week = np.clip(rng.lognormal(mean=0.0, sigma=0.9, size=n_users), 0.15, 20)
    user_country = rng.choice(COUNTRIES, n_users, p=np.array(COUNTRY_W) / sum(COUNTRY_W))
    user_device = rng.choice(DEVICES, n_users, p=DEVICE_W)
    user_ids = np.array([f"u_{i:06d}" for i in range(1, n_users + 1)])

    users_rows, pref_rows, sub_rows = [], [], []
    ev_chunks = []
    sub_seq = 0

    for u in range(n_users):
        uid = user_ids[u]

        # --- taste: 2-5 favourite genres, clustered around one family
        n_fav = rng.integers(2, 6)
        first = rng.choice(len(genres), p=genre_appeal)
        same_family = np.flatnonzero(genre_family == genre_family[first])
        favs = [first]
        while len(favs) < n_fav:
            pool = same_family if rng.random() < 0.6 else np.arange(len(genres))
            g = rng.choice(pool)
            if g not in favs:
                favs.append(g)
        fav_w = rng.dirichlet(np.ones(n_fav) * 1.5)
        order = np.argsort(-fav_w)
        favs, fav_w = np.array(favs)[order], fav_w[order]

        # onboarding: 85 % answer, and they declare what they *think* they like
        if rng.random() < 0.85:
            declared = favs[: max(1, n_fav - rng.integers(0, 2))]
            for rank, g in enumerate(declared):
                affinity = int(np.clip(100 - rank * rng.integers(8, 20) + rng.normal(0, 4), 30, 100))
                pref_rows.append((uid, genres[g], affinity, to_ts(np.array([signup_s[u] + 120]))[0]))

        users_rows.append((
            uid,
            to_ts(np.array([signup_s[u]]))[0],
            user_country[u].lower() if rng.random() < 0.05 else user_country[u],
            int(rng.integers(1960, 2010)),
            rng.choice(CHANNELS, p=CHANNEL_W),
            user_device[u],
            to_ts(np.array([last_active_s[u]]))[0] if churns[u] and last_active_s[u] < horizon else None,
        ))

        # --- subscriptions: freemium funnel
        plan = rng.choice(list(PLANS), p=PLAN_W)
        t = signup_s[u]
        while t < last_active_s[u]:
            if plan == "free":
                # heavier listeners are likelier to upgrade, and upgrades take months, not days
                p_upgrade = float(np.clip(0.004 + 0.11 * sessions_per_week[u] ** 1.5, 0.004, 0.7))
                nxt = t + int(rng.exponential(90 * 86400)) if rng.random() < p_upgrade else horizon + 1
                next_plan = rng.choice(["premium", "student", "family"], p=[0.75, 0.17, 0.08])
            else:
                nxt = t + int(rng.exponential(220 * 86400)) if rng.random() < 0.35 else horizon + 1
                next_plan = "free"
            end = min(nxt, last_active_s[u])
            sub_seq += 1
            raw_plan = plan.upper() if rng.random() < 0.03 else plan
            sub_rows.append((
                f"sub_{sub_seq:07d}", uid, raw_plan, PLANS[plan],
                to_ts(np.array([t]))[0],
                to_ts(np.array([end]))[0] if end < horizon else None,
                "churned" if end == last_active_s[u] and churns[u] else ("plan_change" if end < horizon else None),
            ))
            t, plan = end, next_plan

        # --- sessions
        active_weeks = max((last_active_s[u] - signup_s[u]) / (7 * 86400), 0.15)
        n_sessions = rng.poisson(sessions_per_week[u] * active_weeks)
        if n_sessions == 0:
            continue  # signed up, never listened (cold start)
        day = rng.integers(signup_s[u] // 86400, last_active_s[u] // 86400 + 1, n_sessions)
        weekday = (np.datetime64(SIM_START, "D") + day.astype("timedelta64[D]")).astype("datetime64[D]").view("int64")
        is_weekend = ((weekday + 3) % 7) >= 5  # 1970-01-01 was a Thursday
        hour = np.where(is_weekend,
                        rng.choice(24, n_sessions, p=WEEKEND_HOUR_W),
                        rng.choice(24, n_sessions, p=HOUR_W))
        sess_start = day * 86400 + hour * 3600 + rng.integers(0, 3600, n_sessions)
        sess_start = np.clip(sess_start, signup_s[u], horizon - 3 * 3600)
        sess_len = rng.geometric(1 / 7, n_sessions)
        sess_device = np.where(rng.random(n_sessions) < 0.8, user_device[u], rng.choice(DEVICES, n_sessions, p=DEVICE_W))

        n_ev = int(sess_len.sum())
        sess_of_ev = np.repeat(np.arange(n_sessions), sess_len)
        # stable chronological order of sessions
        sess_order = np.argsort(sess_start, kind="stable")
        rank_of_sess = np.empty(n_sessions, dtype=np.int64)
        rank_of_sess[sess_order] = np.arange(n_sessions)
        ev_sort = np.lexsort((np.arange(n_ev), rank_of_sess[sess_of_ev]))
        sess_of_ev = sess_of_ev[ev_sort]

        # --- which track: favourite genres (82 %) vs exploration, then heavy rotation
        explore = rng.random(n_ev) < 0.18
        g_choice = np.where(explore,
                            rng.choice(len(genres), n_ev, p=genre_appeal),
                            rng.choice(favs, n_ev, p=fav_w))
        tracks = np.empty(n_ev, dtype=np.int64)
        for g in np.unique(g_choice):
            m = g_choice == g
            tracks[m] = rng.choice(genre_tracks[g], m.sum(), p=genre_probs[g])
        rotation = (rng.random(n_ev) < 0.38) & (np.arange(n_ev) > 5)
        pos = np.flatnonzero(rotation)
        src = (rng.random(len(pos)) * pos).astype(np.int64)
        tracks[pos] = tracks[src]  # replaying something heard earlier
        explore[pos] = explore[src]

        # --- outcome of each stream
        p_skip = np.where(rotation, 0.08, np.where(explore, 0.48, 0.20)) + (60 - pops[tracks]) / 600
        skipped = rng.random(n_ev) < np.clip(p_skip, 0.02, 0.9)
        dur = durations[tracks]
        ms_played = np.where(skipped,
                             rng.integers(1500, 30000, n_ev),
                             (dur * np.clip(rng.beta(8, 1.2, n_ev), 0.5, 1)).astype(np.int64))

        # timestamps: tracks play back-to-back within a session
        offsets = np.zeros(n_ev, dtype=np.int64)
        first_of_sess = np.r_[True, sess_of_ev[1:] != sess_of_ev[:-1]]
        step = ms_played // 1000 + rng.integers(0, 4, n_ev)
        cum = np.cumsum(step)
        sess_base = np.maximum.accumulate(np.where(first_of_sess, np.r_[0, cum[:-1]], 0))
        offsets = np.r_[0, cum[:-1]] - sess_base
        ev_at = sess_start[sess_of_ev] + offsets

        ctx_p = np.array([0.36, 0.20, 0.10, 0.12, 0.12, 0.10])
        context = rng.choice(CONTEXTS, n_ev, p=ctx_p)
        before_launch = (ev_at < reco_launch) & (context == "muse_recommendation")
        context[before_launch] = "playlist"

        base = pd.DataFrame({
            "user_id": uid,
            "track_idx": tracks,
            "event_type": np.where(skipped, "skip", "play"),
            "event_s": ev_at,
            "ms_played": ms_played,
            "device": sess_device[sess_of_ev],
            "context": context,
        })

        # engagement events follow a completed play
        played = ~skipped
        fit = np.where(explore, 0.35, 1.0)
        extras = []
        for etype, p, delay in (("like", 0.07, 20), ("add_to_playlist", 0.035, 25), ("repeat", 0.03, 0)):
            m = played & (rng.random(n_ev) < p * fit)
            if m.any():
                e = base[m].copy()
                e["event_type"] = etype
                e["event_s"] = e["event_s"] + np.where(etype == "repeat", dur[m] // 1000, delay)
                e["ms_played"] = dur[m] if etype == "repeat" else 0
                extras.append(e)
        ev_chunks.append(pd.concat([base, *extras], ignore_index=True))

        if (u + 1) % 5000 == 0:
            log(f"  {u + 1:,} users done, {sum(len(c) for c in ev_chunks):,} events so far")

    # ------------------------------------------------------------- assemble
    events = pd.concat(ev_chunks, ignore_index=True)
    events = events[events["event_s"] < horizon]
    events = events.sort_values(["event_s", "user_id"], kind="stable").reset_index(drop=True)
    n = len(events)
    events.insert(0, "event_id", [f"evt_{i:09d}" for i in range(1, n + 1)])
    events["track_id"] = track_ids[events.pop("track_idx").to_numpy()]

    # ingestion noise ------------------------------------------------------
    ev_ts = to_ts(events["event_s"].to_numpy())
    # mobile clients batch-upload: usually seconds, sometimes days later (offline mode)
    delay = np.where(rng.random(n) < 0.03, rng.exponential(2 * 86400, n), rng.exponential(30, n)).astype(np.int64)
    events["ingested_at"] = to_ts(events["event_s"].to_numpy() + delay)
    iso = pd.Series(ev_ts).dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    plain = pd.Series(ev_ts).dt.strftime("%Y-%m-%d %H:%M:%S")
    events["event_at"] = np.where(rng.random(n) < 0.7, iso, plain)  # two client SDK versions
    events = events.drop(columns="event_s")
    casing = rng.random(n)
    events.loc[casing < 0.02, "event_type"] = events.loc[casing < 0.02, "event_type"].str.upper()
    events.loc[rng.random(n) < 0.001, "user_id"] = None             # logged-out plays
    orphan = rng.random(n) < 0.0003                                   # tracks removed from catalog
    events.loc[orphan, "track_id"] = [f"removed_{i:06d}" for i in range(orphan.sum())]
    dupes = events.sample(frac=0.01, random_state=seed)               # at-least-once delivery
    dupes = dupes.assign(ingested_at=dupes["ingested_at"] + pd.Timedelta(minutes=5))
    events = pd.concat([events, dupes], ignore_index=True)
    events = events[["event_id", "user_id", "track_id", "event_type", "event_at", "ms_played",
                     "device", "context", "ingested_at"]]

    users = pd.DataFrame(users_rows, columns=[
        "user_id", "signed_up_at", "country", "birth_year", "acquisition_channel",
        "primary_device", "deleted_at"])
    prefs = pd.DataFrame(pref_rows, columns=["user_id", "genre_name", "affinity", "declared_at"])
    subs = pd.DataFrame(sub_rows, columns=[
        "subscription_id", "user_id", "plan", "monthly_price_eur", "started_at", "ended_at", "end_reason"])

    for name, df in (("app_users", users), ("onboarding_genre_preferences", prefs),
                     ("subscriptions", subs), ("listening_events", events)):
        con.register("df_view", df)
        con.execute(f"create or replace table raw.{name} as select * from df_view")
        con.unregister("df_view")
        log(f"raw.{name:<32} {len(df):>12,} rows")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--users", type=int, default=10_000)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--database", default=str(ROOT / "muse.duckdb"))
    args = parser.parse_args()

    download_catalog()
    con = duckdb.connect(args.database)
    con.execute("create schema if not exists raw")
    con.execute(f"""
        create or replace table raw.spotify_tracks as
        select * exclude (column00), column00 as source_row_number
        from read_csv('{CATALOG_PATH}', header = true, auto_detect = true)
    """)
    log(f"raw.{'spotify_tracks':<32} {con.execute('select count(*) from raw.spotify_tracks').fetchone()[0]:>12,} rows")
    simulate(con, args.users, args.seed)
    con.close()
    log("done")


if __name__ == "__main__":
    main()
