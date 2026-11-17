import re
from datetime import date

from clickstream.generate import generate
from clickstream.transform import LOG_PATTERN


def make(tmp_path, **overrides):
    params = {
        "rows": 2000, "days": 2, "start": date(2026, 4, 6), "seed": 1,
        "bad_rate": 0.0, "bot_share": 0.03, "unique_ips": 50,
    }
    params.update(overrides)
    path = tmp_path / "access.log"
    written = generate(path, params["rows"], params["days"], params["start"], params["seed"],
                       params["bad_rate"], params["bot_share"], params["unique_ips"])
    return path, written


def test_row_count_and_format(tmp_path):
    path, written = make(tmp_path)
    lines = path.read_text().splitlines()
    assert written == len(lines) == 2000
    assert all(re.match(LOG_PATTERN, line) for line in lines)


def test_deterministic_for_same_seed(tmp_path):
    first, _ = make(tmp_path / "a")
    second, _ = make(tmp_path / "b")
    assert first.read_text() == second.read_text()


def test_bad_rate_injects_unparseable_lines(tmp_path):
    path, _ = make(tmp_path, bad_rate=0.2)
    lines = path.read_text().splitlines()
    bad = [line for line in lines if not re.match(LOG_PATTERN, line)]
    assert 0 < len(bad) < len(lines)
