# backend/models.py
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Integer, Boolean, Float
from sqlalchemy.orm import relationship
from database import Base
from datetime import datetime
import uuid

# 사용자 모델(김민식 추가)
class User(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    email = Column(String(255), unique=True, nullable=False, index=True)
    username = Column(String(100), unique=True, nullable=False, index=True)
    hashed_password = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_active = Column(Boolean, default=True)
    
    # 사용자가 생성한 채팅방들
    chat_rooms = relationship("ChatRoom", back_populates="user", cascade="all, delete-orphan")

    folders = relationship("Folder", back_populates="user", cascade="all, delete-orphan")
    pdf_files = relationship("PDFFile", back_populates="user", cascade="all, delete-orphan")

class ChatRoom(Base):
    __tablename__ = "chat_rooms"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False) # 사용자 아이디 외래키 연결(김민식 추가)
    pdf_id = Column(String, ForeignKey("pdf_files.id"), nullable=True)
    title = Column(String(200), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    learning_phase = Column(String(50), default="home")
    current_concept = Column(String(500), nullable=True)
    original_question = Column(Text, nullable=True)  # 원본 질문 저장 (맥락 보존용)
    knowledge_level = Column(Integer, default=0)
    
    user = relationship("User", back_populates="chat_rooms")
    messages = relationship("Message", back_populates="room", cascade="all, delete-orphan")
    linked_pdf = relationship("PDFFile")

class Message(Base):
    __tablename__ = "messages"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    room_id = Column(String, ForeignKey("chat_rooms.id"))
    role = Column(String(50))  # user or assistant
    content = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

    #파인만 학습 필드
    phase = Column(String(50), nullable=True)
    is_explanation = Column(Boolean, default=False)

    room = relationship("ChatRoom", back_populates="messages")

class Folder(Base):
    __tablename__ = "folders"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    name = Column(String(100), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    user = relationship("User", back_populates="folders")
    pdf_files = relationship("PDFFile", back_populates="folder")

class PDFFile(Base):
    __tablename__ = "pdf_files"
    
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    folder_id = Column(String, ForeignKey("folders.id"), nullable=True)  # NULL이면 루트
    filename = Column(String(255), nullable=False)
    original_filename = Column(String(255), nullable=False)  # 사용자가 업로드한 원본 이름
    file_path = Column(String(500), nullable=False)  # 실제 저장 경로
    file_size = Column(Integer, nullable=False)  # 바이트 단위
    page_count = Column(Integer, nullable=True)  # PDF 페이지 수
    uploaded_at = Column(DateTime, default=datetime.utcnow)
    
    user = relationship("User", back_populates="pdf_files")
    folder = relationship("Folder", back_populates="pdf_files")

# ========== Planner 모델 ==========
class Goal(Base):
    """학습 목표 모델"""
    __tablename__ = "goals"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    deadline = Column(DateTime, nullable=False)
    is_completed = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    user = relationship("User")

class Schedule(Base):
    """일정 모델"""
    __tablename__ = "schedules"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    date = Column(DateTime, nullable=False)
    title = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    start_time = Column(String(5), nullable=True)  # HH:MM 형식
    end_time = Column(String(5), nullable=True)    # HH:MM 형식
    is_completed = Column(Boolean, default=False)
    color = Column(Integer, nullable=True)  # Flutter Color.value (ARGB int)

    user = relationship("User")

class Subject(Base):
    """과목 모델 (학점계산기용)"""
    __tablename__ = "subjects"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    name = Column(String(100), nullable=False)
    credits = Column(Float, nullable=False)
    grade = Column(String(2), nullable=False)  # A+, A, B+, B, C+, C, D+, D, F
    year = Column(Integer, nullable=False)     # 학년 (1, 2, 3, 4)
    semester = Column(Integer, nullable=False) # 학기 (1, 2)

    user = relationship("User")

