import pytest

from clickstream.transform import build_session


@pytest.fixture(scope="session")
def spark():
    session = build_session("clickstream-tests", "local[2]", shuffle_partitions=2)
    yield session
    session.stop()
