# backend/schemas.py
from pydantic import BaseModel, EmailStr
from typing import List, Optional
from datetime import datetime

# ===== 사용자 스키마 =====

class UserCreate(BaseModel):
    username: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    created_at: datetime
    
    class Config:
        from_attributes = True

class AuthToken(BaseModel):
    token: str
    user_id: int
    username: str
    email: str

# ===== 채팅방 스키마 =====

class ChatRoomCreate(BaseModel):
    concept: str
    current_phase: str = "explain"

class ChatRoomResponse(BaseModel):
    id: int
    concept: str
    current_phase: str
    created_at: datetime
    user_id: Optional[int] = None
    
    class Config:
        from_attributes = True

class MessageCreate(BaseModel):
    content: str
    sender: str
    phase: Optional[str] = None

class MessageResponse(BaseModel):
    id: int
    room_id: int
    content: str
    sender: str
    phase: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True

# ===== 퀴즈 스키마 =====

class QuizAnswerCreate(BaseModel):
    answer_text: str
    is_correct: bool
    answer_order: int

class QuizAnswerResponse(BaseModel):
    id: int
    answer_text: str
    is_correct: bool
    answer_order: int
    
    class Config:
        from_attributes = True

class QuizQuestionCreate(BaseModel):
    question_text: str
    question_type: str
    question_order: int
    correct_answer: Optional[str] = None
    answers: Optional[List[QuizAnswerCreate]] = None

# [추가됨] 질문 수정을 위한 스키마
class QuizQuestionUpdate(BaseModel):
    question_text: Optional[str] = None
    correct_answer: Optional[str] = None
    answers: Optional[List[QuizAnswerCreate]] = None

class QuizQuestionResponse(BaseModel):
    id: int
    question_text: str
    question_type: str
    question_order: int
    correct_answer: Optional[str]
    answers: List[QuizAnswerResponse]
    
    class Config:
        from_attributes = True

class QuizCreate(BaseModel):
    quiz_name: str
    questions: List[QuizQuestionCreate]

class QuizResponse(BaseModel):
    id: int
    quiz_name: str
    user_id: int
    created_at: datetime
    questions: List[QuizQuestionResponse]
    
    class Config:
        from_attributes = True

# ===== 진행 상황 스키마 =====

class ProgressSubmit(BaseModel):
    quiz_id: int
    results: List[dict]

class ProgressResponse(BaseModel):
    id: int
    user_id: int
    question_id: int
    is_correct: bool
    attempt_count: int
    correct_count: int
    interval_days: int
    next_review_date: datetime
    last_reviewed_at: Optional[datetime]
    
    class Config:
        from_attributes = True