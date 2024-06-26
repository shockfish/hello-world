from sqlalchemy import Column, Date, String, Integer, func
from hello_world import db

class User(db.Model):
    """ User class """

    # Define table name explicitly instead using class name
    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    username = Column(String(60), unique=True)
    birth_date = Column(Date, default=func.now())

    def __repr__(self):
        """ Representative method executed when data fetched from database using query """
        return f"username: {self.username}, birth_date: {self.birth_date}"
