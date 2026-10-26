"""
Copy the MUSE raw layer from the local DuckDB file to BigQuery.

Run `scripts/load_raw_data.py` first. Each `raw.*` table is exported to
Parquet, then loaded with a BigQuery *load job* — free, and allowed in the
BigQuery sandbox (which forbids DML / streaming inserts).

Usage:
    python scripts/load_to_bigquery.py --project my-gcp-project \
        --credentials path/to/service-account.json      # or omit to use gcloud ADC

The dataset location must match the location set on the dbt connection
(EU by default here).
"""

import argparse
from pathlib import Path

import duckdb
from google.cloud import bigquery

ROOT = Path(__file__).resolve().parent.parent
EXPORT_DIR = ROOT / "data" / "export"
TABLES = ["spotify_tracks", "app_users", "onboarding_genre_preferences", "subscriptions", "listening_events"]


def export_parquet(con, table):
    """Export one raw table. Timestamps become UTC microseconds so BigQuery loads them as TIMESTAMP."""
    columns = con.sql(f"describe raw.{table}").fetchall()
    select = ", ".join(
        f"cast({name} as timestamptz) as {name}" if col_type.startswith("TIMESTAMP") else name
        for name, col_type, *_ in columns
    )
    path = EXPORT_DIR / f"{table}.parquet"
    con.execute(f"copy (select {select} from raw.{table}) to '{path}' (format parquet, compression zstd)")
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--project", required=True, help="GCP project id")
    parser.add_argument("--dataset", default="raw")
    parser.add_argument("--location", default="EU")
    parser.add_argument("--credentials", help="service-account JSON key (default: application-default credentials)")
    parser.add_argument("--database", default=str(ROOT / "muse.duckdb"))
    args = parser.parse_args()

    if args.credentials:
        client = bigquery.Client.from_service_account_json(args.credentials, project=args.project)
    else:
        client = bigquery.Client(project=args.project)

    dataset = bigquery.Dataset(f"{args.project}.{args.dataset}")
    dataset.location = args.location
    client.create_dataset(dataset, exists_ok=True)

    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    con = duckdb.connect(args.database, read_only=True)
    con.execute("set TimeZone = 'UTC'")
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.PARQUET,
        write_disposition=bigquery.WriteDisposition.WRITE_TRUNCATE,
    )
    for table in TABLES:
        path = export_parquet(con, table)
        with path.open("rb") as f:
            job = client.load_table_from_file(
                f, f"{args.project}.{args.dataset}.{table}", job_config=job_config, location=args.location
            )
        job.result()
        loaded = client.get_table(f"{args.project}.{args.dataset}.{table}")
        print(f"{args.dataset}.{table:<32} {loaded.num_rows:>12,} rows  ({path.stat().st_size / 1e6:.0f} MB parquet)")
        path.unlink()  # keep the disk footprint small
    con.close()
    print("done — the dbt sources now resolve to", f"`{args.project}.{args.dataset}`")


if __name__ == "__main__":
    main()
