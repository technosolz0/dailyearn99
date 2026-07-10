import os
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.database import Base

@pytest.fixture(scope="session", autouse=True)
def setup_env():
    os.environ["DATABASE_URL"] = "sqlite:///test.db"

@pytest.fixture(scope="session")
def db_engine(setup_env):
    engine = create_engine("sqlite:///test.db")
    Base.metadata.create_all(bind=engine)
    yield engine
    # Cleanup database tables at the end of the test session
    Base.metadata.drop_all(bind=engine)

@pytest.fixture(scope="function")
def db_session(db_engine):
    connection = db_engine.connect()
    transaction = connection.begin()
    Session = sessionmaker(bind=connection)
    session = Session()
    yield session
    session.close()
    transaction.rollback()
    connection.close()
