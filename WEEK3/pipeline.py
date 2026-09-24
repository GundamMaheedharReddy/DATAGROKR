"""
ETL Pipeline: REST API -> pandas transform -> CSV
----------------------------------------------------
Extract:   fetches JSON data from a REST API (GitHub's public search API by default).
Transform: flattens and cleans the JSON with pandas (column selection, dedup,
           null-handling, date parsing).
Load:      writes the resulting DataFrame to a CSV file.

Run directly to execute the full pipeline against the real API:
    python pipeline.py
"""

from __future__ import annotations
import logging
from pathlib import Path
from typing import Any, Dict, List

import pandas as pd
import requests

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
logger = logging.getLogger(__name__)


class ETLPipeline:
    """A small, testable ETL pipeline: Extract -> Transform -> Load."""

    #: columns kept from the raw API payload, in priority order (only kept if present)
    COLUMNS = [
        "id", "name", "full_name", "owner.login", "html_url",
        "description", "language", "stargazers_count", "forks_count",
        "open_issues_count", "created_at", "updated_at",
    ]

    def __init__(self, api_url: str, output_path: str = "output/data.csv", timeout: int = 10):
        self.api_url = api_url
        self.output_path = output_path
        self.timeout = timeout

    # ------------------------------------------------------------------ #
    # EXTRACT
    # ------------------------------------------------------------------ #
    def extract(self) -> List[Dict[str, Any]]:
        """Fetch raw JSON from the REST API and normalize it to a list of records."""
        logger.info("Extracting data from %s", self.api_url)
        response = requests.get(
            self.api_url,
            headers={"Accept": "application/vnd.github+json"},
            timeout=self.timeout,
        )
        response.raise_for_status()
        payload = response.json()

        if isinstance(payload, dict) and "items" in payload:
            records = payload["items"]
        elif isinstance(payload, dict):
            records = [payload]
        else:
            records = payload

        logger.info("Extracted %d records", len(records))
        return records

    # ------------------------------------------------------------------ #
    # TRANSFORM
    # ------------------------------------------------------------------ #
    def transform(self, raw_data: List[Dict[str, Any]]) -> pd.DataFrame:
        """Flatten nested JSON and clean it into a tidy DataFrame."""
        if not raw_data:
            logger.warning("No data to transform; returning empty DataFrame")
            return pd.DataFrame()

        df = pd.json_normalize(raw_data)

        # Keep only the columns we care about, if present
        cols = [c for c in self.COLUMNS if c in df.columns]
        if cols:
            df = df[cols]

        df = df.drop_duplicates()
        df = df.dropna(axis=1, how="all")

        for date_col in ("created_at", "updated_at"):
            if date_col in df.columns:
                df[date_col] = pd.to_datetime(df[date_col], errors="coerce")

        if "description" in df.columns:
            df["description"] = df["description"].fillna("No description")

        if "owner.login" in df.columns:
            df = df.rename(columns={"owner.login": "owner"})

        df = df.reset_index(drop=True)
        logger.info("Transformed data: %d rows, %d columns", *df.shape)
        return df

    # ------------------------------------------------------------------ #
    # LOAD
    # ------------------------------------------------------------------ #
    def load(self, df: pd.DataFrame) -> str:
        """Write the DataFrame to CSV, creating parent directories as needed."""
        out_path = Path(self.output_path)
        out_path.parent.mkdir(parents=True, exist_ok=True)
        df.to_csv(out_path, index=False)
        logger.info("Loaded %d rows to %s", len(df), out_path)
        return str(out_path)

    # ------------------------------------------------------------------ #
    # ORCHESTRATION
    # ------------------------------------------------------------------ #
    def run(self) -> pd.DataFrame:
        """Run the full Extract -> Transform -> Load pipeline."""
        raw = self.extract()
        df = self.transform(raw)
        self.load(df)
        return df


if __name__ == "__main__":
    pipeline = ETLPipeline(
        api_url="https://api.github.com/search/repositories?q=language:python&sort=stars&order=desc&per_page=25",
        output_path="output/top_python_repos.csv",
    )
    result = pipeline.run()
    print(result.head(10).to_string())
