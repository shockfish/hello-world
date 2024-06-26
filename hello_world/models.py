from sqlalchemy import Column, Date, String, Integer, func
from hello_world import db

class User(db.Model):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    username = Column(String(60), unique=True)
    birth_date = Column(Date, default=func.now())

    def __repr__(self):
        return f"id: {self.id}, username: {self.username}, birth date: {self.birth_date}"