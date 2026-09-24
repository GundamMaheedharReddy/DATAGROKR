"""
Unit tests for the ETL pipeline.

Run with:
    pytest test_pipeline.py -v
"""

from pathlib import Path
from unittest.mock import Mock, patch

import pandas as pd
import pytest
import requests

from pipeline import ETLPipeline


# --------------------------------------------------------------------------- #
# Fixtures
# --------------------------------------------------------------------------- #
SAMPLE_ITEMS = [
    {
        "id": 1,
        "name": "requests",
        "full_name": "psf/requests",
        "owner": {"login": "psf"},
        "html_url": "https://github.com/psf/requests",
        "description": "A simple, elegant HTTP library.",
        "language": "Python",
        "stargazers_count": 50000,
        "forks_count": 9000,
        "open_issues_count": 100,
        "created_at": "2011-02-13T18:38:17Z",
        "updated_at": "2024-01-01T00:00:00Z",
    },
    {
        "id": 2,
        "name": "flask",
        "full_name": "pallets/flask",
        "owner": {"login": "pallets"},
        "html_url": "https://github.com/pallets/flask",
        "description": None,               # deliberately missing, to test null-handling
        "language": "Python",
        "stargazers_count": 65000,
        "forks_count": 15000,
        "open_issues_count": 50,
        "created_at": "2010-04-06T11:11:59Z",
        "updated_at": "2024-02-01T00:00:00Z",
    },
]

SAMPLE_SEARCH_RESPONSE = {"total_count": 2, "items": SAMPLE_ITEMS}


@pytest.fixture
def pipeline(tmp_path):
    """A pipeline instance writing to a temp file, so tests never touch real disk state."""
    output_file = tmp_path / "repos.csv"
    return ETLPipeline(
        api_url="https://api.github.com/search/repositories?q=test",
        output_path=str(output_file),
    )


def make_mock_response(json_data, status_ok=True):
    mock_resp = Mock()
    mock_resp.json.return_value = json_data
    if status_ok:
        mock_resp.raise_for_status.return_value = None
    else:
        mock_resp.raise_for_status.side_effect = requests.exceptions.HTTPError("404 Not Found")
    return mock_resp


# --------------------------------------------------------------------------- #
# EXTRACT
# --------------------------------------------------------------------------- #
class TestExtract:
    @patch("pipeline.requests.get")
    def test_extract_unwraps_items_key(self, mock_get, pipeline):
        mock_get.return_value = make_mock_response(SAMPLE_SEARCH_RESPONSE)

        result = pipeline.extract()

        assert isinstance(result, list)
        assert len(result) == 2
        assert result[0]["name"] == "requests"

    @patch("pipeline.requests.get")
    def test_extract_wraps_single_dict_without_items(self, mock_get, pipeline):
        mock_get.return_value = make_mock_response({"id": 1, "name": "solo-repo"})

        result = pipeline.extract()

        assert result == [{"id": 1, "name": "solo-repo"}]

    @patch("pipeline.requests.get")
    def test_extract_passes_through_a_plain_list(self, mock_get, pipeline):
        mock_get.return_value = make_mock_response(SAMPLE_ITEMS)

        result = pipeline.extract()

        assert result == SAMPLE_ITEMS

    @patch("pipeline.requests.get")
    def test_extract_raises_on_http_error(self, mock_get, pipeline):
        mock_get.return_value = make_mock_response({}, status_ok=False)

        with pytest.raises(requests.exceptions.HTTPError):
            pipeline.extract()

    @patch("pipeline.requests.get")
    def test_extract_calls_correct_url_and_headers(self, mock_get, pipeline):
        mock_get.return_value = make_mock_response(SAMPLE_SEARCH_RESPONSE)

        pipeline.extract()

        called_args, called_kwargs = mock_get.call_args
        assert called_args[0] == pipeline.api_url
        assert called_kwargs["headers"]["Accept"] == "application/vnd.github+json"


# --------------------------------------------------------------------------- #
# TRANSFORM
# --------------------------------------------------------------------------- #
class TestTransform:
    def test_transform_returns_dataframe_with_correct_row_count(self, pipeline):
        df = pipeline.transform(SAMPLE_ITEMS)

        assert isinstance(df, pd.DataFrame)
        assert len(df) == 2

    def test_transform_keeps_only_expected_columns(self, pipeline):
        df = pipeline.transform(SAMPLE_ITEMS)

        expected = {"id", "name", "full_name", "owner", "html_url", "description",
                    "language", "stargazers_count", "forks_count",
                    "open_issues_count", "created_at", "updated_at"}
        assert set(df.columns) == expected

    def test_transform_flattens_nested_owner_field(self, pipeline):
        df = pipeline.transform(SAMPLE_ITEMS)

        assert "owner" in df.columns
        assert df.loc[df["name"] == "requests", "owner"].iloc[0] == "psf"

    def test_transform_fills_missing_description(self, pipeline):
        df = pipeline.transform(SAMPLE_ITEMS)

        flask_desc = df.loc[df["name"] == "flask", "description"].iloc[0]
        assert flask_desc == "No description"

    def test_transform_parses_date_columns(self, pipeline):
        df = pipeline.transform(SAMPLE_ITEMS)

        assert pd.api.types.is_datetime64_any_dtype(df["created_at"])
        assert pd.api.types.is_datetime64_any_dtype(df["updated_at"])

    def test_transform_drops_exact_duplicate_rows(self, pipeline):
        duplicated = SAMPLE_ITEMS + [SAMPLE_ITEMS[0]]

        df = pipeline.transform(duplicated)

        assert len(df) == 2

    def test_transform_empty_list_returns_empty_dataframe(self, pipeline):
        df = pipeline.transform([])

        assert isinstance(df, pd.DataFrame)
        assert df.empty


# --------------------------------------------------------------------------- #
# LOAD
# --------------------------------------------------------------------------- #
class TestLoad:
    def test_load_creates_csv_file(self, pipeline):
        df = pipeline.transform(SAMPLE_ITEMS)

        path = pipeline.load(df)

        assert Path(path).exists()

    def test_load_creates_parent_directories(self, tmp_path):
        nested_path = tmp_path / "nested" / "dir" / "out.csv"
        p = ETLPipeline(api_url="dummy", output_path=str(nested_path))
        df = p.transform(SAMPLE_ITEMS)

        p.load(df)

        assert nested_path.exists()

    def test_load_writes_correct_row_count(self, pipeline):
        df = pipeline.transform(SAMPLE_ITEMS)

        path = pipeline.load(df)
        reloaded = pd.read_csv(path)

        assert len(reloaded) == len(df)

    def test_load_preserves_column_values(self, pipeline):
        df = pipeline.transform(SAMPLE_ITEMS)

        path = pipeline.load(df)
        reloaded = pd.read_csv(path)

        assert sorted(reloaded["name"]) == sorted(df["name"])
        assert sorted(reloaded["stargazers_count"]) == sorted(df["stargazers_count"])


# --------------------------------------------------------------------------- #
# END-TO-END
# --------------------------------------------------------------------------- #
class TestRun:
    @patch("pipeline.requests.get")
    def test_run_executes_full_pipeline(self, mock_get, pipeline):
        mock_get.return_value = make_mock_response(SAMPLE_SEARCH_RESPONSE)

        df = pipeline.run()

        assert not df.empty
        assert Path(pipeline.output_path).exists()

    @patch("pipeline.requests.get")
    def test_run_propagates_extract_errors(self, mock_get, pipeline):
        mock_get.return_value = make_mock_response({}, status_ok=False)

        with pytest.raises(requests.exceptions.HTTPError):
            pipeline.run()
