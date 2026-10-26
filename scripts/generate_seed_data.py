"""
Generate the synthetic raw data used as dbt seeds for the MUSE project.

All data is fictional. The generator is deterministic (fixed random seed) so
the CSV files committed in `seeds/` can be rebuilt byte-for-byte:

    python scripts/generate_seed_data.py

Some light "dirt" is injected on purpose (duplicate events, inconsistent
casing, stray whitespace) so the staging layer has real cleaning to do.
"""

import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

random.seed(42)

SEEDS_DIR = Path(__file__).resolve().parent.parent / "seeds"
START = datetime(2026, 1, 1)
END = datetime(2026, 9, 30)

GENRES = [
    # genre, parent family
    ("Pop", "Pop"),
    ("Synth Pop", "Pop"),
    ("Indie Pop", "Pop"),
    ("Dance Pop", "Pop"),
    ("Dream Pop", "Pop"),
    ("Indie Rock", "Rock"),
    ("Alternative Rock", "Rock"),
    ("Hip Hop", "Hip Hop"),
    ("Trap", "Hip Hop"),
    ("R&B", "R&B"),
    ("Neo Soul", "R&B"),
    ("House", "Electronic"),
    ("Techno", "Electronic"),
    ("Lo-fi", "Electronic"),
    ("Jazz", "Jazz"),
]

ARTIST_NAMES = [
    "Nova Lane", "The Paper Kites Club", "Luma", "Static Bloom", "Orchid Avenue",
    "Kairo", "Mira Sol", "Velvet Static", "Echo Park Kids", "Juno Rae",
    "Neon Tides", "Atlas & Ivy", "Sable", "Hollow Pines", "Frankie Blue",
    "Coastline", "Midnight Society", "Ravi Moon", "Glass Animals Fan Club", "Aurora Fields",
    "Lowkey Lou", "Saint Marlo", "Polar Haze", "Iris Vale", "The Bluebirds",
]

TITLE_A = ["Midnight", "Golden", "Electric", "City", "Soft", "Neon", "Ocean", "Paper",
           "Velvet", "Northern", "Silver", "Summer", "Broken", "Wild", "Quiet", "Crystal",
           "Purple", "Lonely", "Burning", "Faded"]
TITLE_B = ["Drive", "Hour", "Heart", "Lights", "Focus", "Rain", "Avenue", "Planes", "Sky",
           "Echo", "Lines", "Nights", "Dreams", "Waves", "Signals", "Roads", "Fever",
           "Garden", "Mirrors", "Static"]

N_TRACKS = 120
N_USERS = 60
COUNTRIES = ["FR", "US", "GB", "DE", "ES", "CA", "BE", "BR"]
PLANS = ["free", "premium", "student"]


def rand_date(start, end):
    delta = end - start
    return start + timedelta(seconds=random.randint(0, int(delta.total_seconds())))


def write_csv(name, header, rows):
    path = SEEDS_DIR / f"{name}.csv"
    with path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(header)
        writer.writerows(rows)
    print(f"wrote {len(rows):>5} rows -> {path.relative_to(SEEDS_DIR.parent)}")


def main():
    SEEDS_DIR.mkdir(exist_ok=True)

    # --- genres -----------------------------------------------------------
    write_csv("raw_genres", ["genre_name", "parent_genre"], GENRES)
    genre_names = [g for g, _ in GENRES]

    # --- artists ----------------------------------------------------------
    artists = []
    for i, name in enumerate(ARTIST_NAMES, start=1):
        artists.append({
            "artist_id": f"ART{i:03d}",
            "artist_name": name,
            "primary_genre": random.choice(genre_names),
            "country": random.choice(COUNTRIES),
        })
    write_csv(
        "raw_artists",
        ["artist_id", "artist_name", "primary_genre", "country"],
        [[a["artist_id"], a["artist_name"], a["primary_genre"], a["country"]] for a in artists],
    )

    # --- tracks -----------------------------------------------------------
    tracks = []
    used_titles = set()
    for i in range(1, N_TRACKS + 1):
        while True:
            title = f"{random.choice(TITLE_A)} {random.choice(TITLE_B)}"
            if title not in used_titles:
                used_titles.add(title)
                break
        artist = random.choice(artists)
        # 75% of tracks share the artist's primary genre, the rest are side projects
        genre = artist["primary_genre"] if random.random() < 0.75 else random.choice(genre_names)
        # inject casing / whitespace noise in ~10% of rows
        raw_genre = genre
        if random.random() < 0.1:
            raw_genre = f"  {genre.lower()} "
        tracks.append({
            "track_id": f"TRK{i:04d}",
            "title": title,
            "artist_id": artist["artist_id"],
            "genre": genre,
            "raw_genre": raw_genre,
            "release_date": rand_date(datetime(2015, 1, 1), datetime(2026, 6, 30)).date().isoformat(),
            "duration_ms": random.randint(140_000, 300_000),
            "explicit": random.random() < 0.2,
            # a latent "hit factor" drives how often the track gets streamed
            "hit_factor": random.paretovariate(1.6),
        })
    write_csv(
        "raw_tracks",
        ["track_id", "title", "artist_id", "genre", "release_date", "duration_ms", "is_explicit"],
        [[t["track_id"], t["title"], t["artist_id"], t["raw_genre"], t["release_date"],
          t["duration_ms"], str(t["explicit"]).lower()] for t in tracks],
    )

    # --- users ------------------------------------------------------------
    users = []
    for i in range(1, N_USERS + 1):
        signup = rand_date(datetime(2025, 6, 1), datetime(2026, 9, 15))
        users.append({
            "user_id": f"USR{i:04d}",
            "username": f"listener_{i:03d}",
            "country": random.choice(COUNTRIES),
            "plan": random.choice(PLANS),
            "signed_up_at": signup,
            "birth_year": random.randint(1970, 2008),
        })
    write_csv(
        "raw_users",
        ["user_id", "username", "country", "subscription_plan", "signed_up_at", "birth_year"],
        [[u["user_id"], u["username"], u["country"], u["plan"].upper() if random.random() < 0.15 else u["plan"],
          u["signed_up_at"].isoformat(sep=" "), u["birth_year"]] for u in users],
    )

    # --- onboarding genre preferences ------------------------------------
    prefs = []
    user_fav_genres = {}
    for u in users:
        favs = random.sample(genre_names, k=random.randint(2, 4))
        user_fav_genres[u["user_id"]] = favs
        for rank, g in enumerate(favs):
            affinity = max(40, 100 - rank * random.randint(8, 18))
            prefs.append([u["user_id"], g, affinity, u["signed_up_at"].isoformat(sep=" ")])
    write_csv("raw_user_genre_preferences", ["user_id", "genre_name", "affinity", "declared_at"], prefs)

    # --- listening events -------------------------------------------------
    # ~10% of users are brand new (cold start): no listening history at all.
    cold_start_users = set(random.sample([u["user_id"] for u in users], k=N_USERS // 10))
    events = []
    event_seq = 0
    for u in users:
        if u["user_id"] in cold_start_users:
            continue
        favs = user_fav_genres[u["user_id"]]
        n_sessions = random.randint(15, 70)
        # each user has a handful of "comfort" tracks among their fav genres
        candidates = [t for t in tracks if t["genre"] in favs] or tracks
        weights = [t["hit_factor"] * (3 if t["genre"] in favs else 1) for t in tracks]
        for _ in range(n_sessions):
            pool_is_fav = random.random() < 0.7
            if pool_is_fav:
                track = random.choices(candidates, weights=[t["hit_factor"] for t in candidates])[0]
            else:
                track = random.choices(tracks, weights=weights)[0]
            ts = rand_date(max(u["signed_up_at"], START), END)
            liked_genre = track["genre"] in favs
            skip_prob = 0.15 if liked_genre else 0.5
            event_seq += 1
            if random.random() < skip_prob:
                ms_played = random.randint(3_000, 30_000)
                events.append([f"EVT{event_seq:06d}", u["user_id"], track["track_id"], "skip",
                               ts.isoformat(sep=" "), ms_played])
                continue
            ms_played = random.randint(int(track["duration_ms"] * 0.6), track["duration_ms"])
            events.append([f"EVT{event_seq:06d}", u["user_id"], track["track_id"], "play",
                           ts.isoformat(sep=" "), ms_played])
            if random.random() < (0.25 if liked_genre else 0.05):
                event_seq += 1
                events.append([f"EVT{event_seq:06d}", u["user_id"], track["track_id"],
                               random.choice(["like", "LIKE", "Like"]),
                               (ts + timedelta(seconds=30)).isoformat(sep=" "), 0])
            if random.random() < (0.15 if liked_genre else 0.02):
                event_seq += 1
                events.append([f"EVT{event_seq:06d}", u["user_id"], track["track_id"], "repeat",
                               (ts + timedelta(seconds=track["duration_ms"] // 1000)).isoformat(sep=" "),
                               track["duration_ms"]])

    # duplicated ingestion: re-send ~2% of events with the same event_id
    dupes = random.sample(events, k=len(events) // 50)
    events.extend(dupes)
    events.sort(key=lambda e: e[4])
    write_csv("raw_listening_events",
              ["event_id", "user_id", "track_id", "event_type", "event_at", "ms_played"], events)


if __name__ == "__main__":
    main()
