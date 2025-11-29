# backend/models.py (통합 버전)
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Integer, Boolean
from sqlalchemy.orm import relationship
from database import Base
from datetime import datetime
import uuid

# ========== 기존 파인만 학습 모델 ==========

class ChatRoom(Base):
    __tablename__ = "chat_rooms"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    title = Column(String(200), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    learning_phase = Column(String(50), default="home")
    current_concept = Column(String(500), nullable=True)
    knowledge_level = Column(Integer, default=0)
    
    # 사용자 연결 추가
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    
    messages = relationship("Message", back_populates="room", cascade="all, delete-orphan")
    user = relationship("User", back_populates="chat_rooms")

class Message(Base):
    __tablename__ = "messages"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    room_id = Column(String, ForeignKey("chat_rooms.id"))
    role = Column(String(50))  # user or assistant
    content = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

    # 파인만 학습 필드
    phase = Column(String(50), nullable=True)
    is_explanation = Column(Boolean, default=False)

    room = relationship("ChatRoom", back_populates="messages")

# ========== 새로 추가: 사용자 인증 모델 ==========

class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(100), unique=True, nullable=False, index=True)
    email = Column(String(100), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    chat_rooms = relationship("ChatRoom", back_populates="user")
    quizzes = relationship("Quiz", back_populates="user", cascade="all, delete-orphan")
    progress = relationship("UserProgress", back_populates="user", cascade="all, delete-orphan")

# ========== 새로 추가: 퀴즈 시스템 모델 ==========

class Quiz(Base):
    __tablename__ = "quizzes"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    quiz_name = Column(String(200), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    user = relationship("User", back_populates="quizzes")
    questions = relationship("QuizQuestion", back_populates="quiz", cascade="all, delete-orphan")

class QuizQuestion(Base):
    __tablename__ = "quiz_questions"
    
    id = Column(Integer, primary_key=True, index=True)
    quiz_id = Column(Integer, ForeignKey("quizzes.id"), nullable=False)
    question_text = Column(Text, nullable=False)
    question_type = Column(String(50), default="multiple_choice")  # multiple_choice, short_answer
    question_order = Column(Integer, nullable=False)
    correct_answer = Column(Text, nullable=True)  # 서술형 정답
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Relationships
    quiz = relationship("Quiz", back_populates="questions")
    answers = relationship("QuizAnswer", back_populates="question", cascade="all, delete-orphan")
    progress = relationship("UserProgress", back_populates="question", cascade="all, delete-orphan")

class QuizAnswer(Base):
    __tablename__ = "quiz_answers"
    
    id = Column(Integer, primary_key=True, index=True)
    question_id = Column(Integer, ForeignKey("quiz_questions.id"), nullable=False)
    answer_text = Column(Text, nullable=False)
    is_correct = Column(Boolean, default=False)
    answer_order = Column(Integer, nullable=False)
    
    # Relationships
    question = relationship("QuizQuestion", back_populates="answers")

class UserProgress(Base):
    __tablename__ = "user_progress"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    question_id = Column(Integer, ForeignKey("quiz_questions.id"), nullable=False)
    last_attempted = Column(DateTime, default=datetime.utcnow)
    correct_count = Column(Integer, default=0)
    total_attempts = Column(Integer, default=0)
    next_review_date = Column(DateTime, nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="progress")
    question = relationship("QuizQuestion", back_populates="progress")