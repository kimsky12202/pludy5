from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi import Header
from sqlalchemy.orm import Session
from typing import List, Optional, Dict
from database import engine, get_db, SessionLocal
from pydantic import BaseModel, Field, ConfigDict
from datetime import datetime
import httpx
import json
import models
import socket
import asyncio
import os


from feynman_prompts import LearningPhase, feynman_engine
from evaluation_system import evaluator
from learning_flow import flow_manager
from auth import get_password_hash, verify_password, create_access_token, decode_access_token
from fastapi import File, UploadFile, Form
from rag_system import rag_system
from fastapi.staticfiles import StaticFiles

# Quiz 관련 import
from quiz_generator import generate_quiz_from_text
from pdf_utils import extract_text_from_pdf, truncate_text
from datetime import timedelta
from io import BytesIO

# JWT 인증을 위한 보안 스키마
security = HTTPBearer()

# 데이터베이스 테이블 생성
models.Base.metadata.create_all(bind=engine)

app = FastAPI()

# uploads 폴더 생성
os.makedirs("uploads", exist_ok=True)

# 실제 IP 주소 확인
def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
    finally:
        s.close()
    return ip

LOCAL_IP = get_local_ip()
print(f"Server IP: {LOCAL_IP}:8000")

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

if not os.path.exists("uploads"):
    os.makedirs("uploads")

app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# ========== 기존 Pydantic 모델 ==========
class ChatRoomCreate(BaseModel):
    title: str

class MessageResponse(BaseModel):
    id: str
    role: str
    content: str
    created_at: datetime
    
    class Config:
        from_attributes = True

class ChatRoomResponse(BaseModel):
    id: str
    title: str
    created_at: datetime
    updated_at: datetime
    current_concept: Optional[str] = None
    learning_phase: Optional[str] = None

    class Config:
        from_attributes = True

# ========== 새로운 Pydantic 모델 (파인만) ==========
class PhaseTransitionRequest(BaseModel):
    room_id: str
    user_choice: Optional[str] = None
    message: Optional[str] = None

class PhaseResponse(BaseModel):
    current_phase: str
    next_phase: str
    instruction: str
    title: str

class MessageCreate(BaseModel):
    content: str
    role: str
    phase: str

class KeywordExtractionRequest(BaseModel):
    text: str

class KeywordExtractionResponse(BaseModel):
    original_text: str
    extracted_keyword: str

class InitializeLearningRequest(BaseModel):
    concept: str

# ========== 인증 관련 Pydantic 모델 ==========
class UserRegister(BaseModel):
    email: str
    username: str
    password: str

class UserLogin(BaseModel):
    email: str
    password: str

class UserResponse(BaseModel):
    id: str
    email: str
    username: str
    created_at: datetime
    
    class Config:
        from_attributes = True

class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse

# ========== PDF 및 폴더 관련 Pydantic 모델 ==========
class FolderCreate(BaseModel):
    name: str

class FolderResponse(BaseModel):
    id: str
    user_id: str
    name: str
    created_at: datetime
    
    class Config:
        from_attributes = True

class PDFFileResponse(BaseModel):
    id: str
    user_id: str
    folder_id: Optional[str]
    filename: str
    original_filename: str
    file_path: str
    file_size: int
    page_count: Optional[int]
    uploaded_at: datetime
    
    class Config:
        from_attributes = True

class PDFMoveRequest(BaseModel):
    folder_id: Optional[str]  # None이면 루트로 이동



# ========== 인증 의존성 함수 ==========
async def get_current_user(
    authorization: str = Header(None),
    db: Session = Depends(get_db)
) -> models.User:
    """현재 인증된 사용자 반환"""
    print(f"🔍 Authorization 헤더: {authorization}")
    
    if not authorization:
        print("❌ Authorization 헤더 없음")
        raise HTTPException(status_code=401, detail="Not authenticated")
    
    # Bearer 토큰 파싱
    try:
        scheme, token = authorization.split()
        print(f"🔍 Scheme: {scheme}, Token 앞 20자: {token[:20]}...")
        
        if scheme.lower() != 'bearer':
            print(f"❌ 잘못된 scheme: {scheme}")
            raise HTTPException(status_code=401, detail="Invalid authentication scheme")
    except ValueError:
        print("❌ Authorization 헤더 파싱 실패")
        raise HTTPException(status_code=401, detail="Invalid authorization header")
    
    # auth.py의 decode_access_token 사용 (변경!)
    try:
        payload = decode_access_token(token)  # 여기 변경!
        print(f"✅ JWT 디코딩 성공: {payload}")
        user_id: str = payload.get("sub")
        
        if user_id is None:
            print("❌ 토큰에 user_id 없음")
            raise HTTPException(status_code=401, detail="Invalid token")
    except Exception as e:  # JWTError 대신 Exception
        print(f"❌ JWT 디코딩 실패: {e}")
        raise HTTPException(status_code=401, detail="Could not validate credentials")
    
    # 사용자 조회
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if user is None:
        print(f"❌ 사용자 없음: {user_id}")
        raise HTTPException(status_code=401, detail="User not found")
    
    print(f"✅ 인증 성공: {user.email}")
    return user

# ========== 키워드 추출 함수 (새로 추가) ==========
async def extract_concept_keyword(user_message: str) -> str:
    """사용자 질문에서 핵심 개념 키워드 추출"""
    
    extraction_prompt = f"""다음 질문에서 핵심 키워드를 추출하세요.

질문: {user_message}

매우 중요한 규칙:
1. 원본 질문에 있는 단어만 사용하세요 (새로운 단어 추가 절대 금지!)
2. 질문 어미만 제거하세요 ("-뭐야?", "-이야?", "-인가요?", "알려줘", "설명해줘", "에 대해" 등)
3. 핵심 개념/주제는 그대로 유지
4. 짧은 질문은 전체가 키워드일 수 있음
5. 긴 질문도 의문형 어미만 제거하고 내용은 유지
6. 원본에 없는 단어를 절대 추가하지 마세요!

좋은 예 (원본 단어만 사용):
질문: "빅데이터의 개념이 뭐야?" → 빅데이터의 개념
질문: "입출력 모듈이 메세지를 인식하는 과정" → 입출력 모듈이 메세지를 인식하는 과정
질문: "머신러닝 알고리즘 설명해줘" → 머신러닝 알고리즘
질문: "자료구조에 대해 알려줘" → 자료구조

나쁜 예 (원본에 없는 단어 추가 - 절대 금지):
질문: "입출력 모듈이 메세지를 인식하는 과정" → 입출력 모듈, 프로세싱, 데이터 전달 (❌ "프로세싱", "데이터 전달"은 원본에 없음)
질문: "빅데이터의 개념이 뭐야?" → 빅데이터, 정의, 특징 (❌ "정의", "특징"은 원본에 없음)
질문: "자료구조에 대해서 알려줘" → 자료구조에서 추출한 키워드는 자료구조입니다 (❌ 설명 포함)

원본 질문의 단어만 사용해서 키워드 출력:"""

    try:
        async with httpx.AsyncClient() as client:
            print(f"🔍 키워드 추출 중: '{user_message}'")
            response = await client.post(
                "http://localhost:11434/api/generate",
                json={
                    "model": "llama3.1:8b",
                    "prompt": extraction_prompt,
                    "stream": False
                },
                timeout=15.0
            )
            
            if response.status_code == 200:
                result = response.json()
                keyword = result.get("response", "").strip()

                # 첫 줄만 가져오기 (추가 설명 제거)
                keyword = keyword.split('\n')[0].strip()

                # "에서 추출한 키워드는", "키워드:" 등의 패턴 제거
                import re
                # "~에서 추출한 키워드는" 패턴 제거
                keyword = re.sub(r'.*(에서\s*추출한\s*키워드는?|키워드는?)\s*', '', keyword)
                # "입니다", ".", ":" 등 제거
                keyword = re.sub(r'[.:!?]$', '', keyword)
                keyword = keyword.replace('입니다', '').replace('습니다', '').strip()

                # 따옴표 제거
                keyword = keyword.strip('"\'')

                print(f"✅ 추출된 키워드: '{keyword}'")
                return keyword if keyword else user_message
            else:
                print(f"⚠️ 키워드 추출 실패 (상태: {response.status_code}), 원본 사용")
                return user_message
    except Exception as e:
        print(f"⚠️ 키워드 추출 오류: {e}, 원본 사용")
        return user_message

# ========== RAG 쿼리 생성 함수 (학습 단계별 최적화) ==========
def get_rag_query_for_phase(phase: LearningPhase, concept: str, message: str, original_question: str = None) -> str:
    """
    학습 단계에 맞는 RAG 검색 쿼리 생성

    Args:
        phase: 현재 학습 단계
        concept: 추출된 키워드
        message: 사용자의 현재 메시지
        original_question: 원본 질문 (맥락 정보)

    Returns:
        최적화된 RAG 검색 쿼리
    """

    # 기본 쿼리: 개념 + 현재 메시지
    base_query = f"{concept} {message}".strip()

    if phase == LearningPhase.KNOWLEDGE_CHECK:
        # 지식 확인 단계: 기본 개념 정의와 설명 검색
        query = f"{concept} 정의 개념 설명"
        if original_question:
            # 원본 질문에서 맥락 키워드 추출하여 추가
            query = f"{query} {original_question}"
        return query

    elif phase == LearningPhase.AI_EXPLANATION:
        # AI 설명 단계: 상세 설명, 예시, 비유 관련 자료 검색
        query = f"{concept} 설명 예시 비유"
        if original_question:
            query = f"{query} {original_question}"
        return query

    elif phase == LearningPhase.EVALUATION:
        # 평가 단계: 평가 기준, 핵심 요소 관련 자료 검색
        return f"{concept} 핵심 요소 평가 기준"

    elif phase in [LearningPhase.FIRST_EXPLANATION, LearningPhase.SECOND_EXPLANATION]:
        # 설명 단계: 현재 메시지(사용자 설명)와 관련된 내용 검색
        if original_question:
            return f"{concept} {message} {original_question}"
        return base_query

    elif phase in [LearningPhase.SELF_REFLECTION_1, LearningPhase.SELF_REFLECTION_2]:
        # 자기 성찰 단계: 일반적인 검색
        return base_query

    else:
        # 기타 단계: 기본 쿼리 사용
        return base_query

# ========== 기존 엔드포인트 유지 ==========
@app.get("/")
async def root():
    return {"message": "Backend is running", "ip": LOCAL_IP}

@app.get("/test-ollama")
async def test_ollama():
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "http://localhost:11434/api/generate",
                json={
                    "model": "llama3.1:8b",
                    "prompt": "Say hello in Korean",
                    "stream": False
                },
                timeout=30.0
            )
            
            if response.status_code == 200:
                return {"status": "success", "response": response.json()}
            else:
                return {"status": "error", "code": response.status_code}
                
    except httpx.ConnectError:
        return {"status": "error", "message": "Cannot connect to Ollama"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

# ========== 인증 관련 엔드포인트 ==========
@app.post("/api/auth/register", response_model=UserResponse)
def register_user(user_data: UserRegister, db: Session = Depends(get_db)):
    """회원가입"""
    try:
        # 이메일 중복 확인
        existing_user = db.query(models.User).filter(
            models.User.email == user_data.email
        ).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Email already registered")
        
        # 사용자명 중복 확인
        existing_username = db.query(models.User).filter(
            models.User.username == user_data.username
        ).first()
        if existing_username:
            raise HTTPException(status_code=400, detail="Username already taken")
        
        # 비밀번호 해싱
        hashed_password = get_password_hash(user_data.password)
        
        # 새 사용자 생성
        new_user = models.User(
            email=user_data.email,
            username=user_data.username,
            hashed_password=hashed_password
        )
        
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        print(f"✅ 새 사용자 등록: {new_user.email} ({new_user.username})")
        return new_user
    except HTTPException:
        raise
    except Exception as e:
        import traceback
        error_detail = traceback.format_exc()
        print(f"❌ 회원가입 오류 발생!")
        print(f"❌ 에러 타입: {type(e).__name__}")
        print(f"❌ 에러 메시지: {str(e)}")
        print(f"❌ 상세 스택:")
        print(error_detail)
        raise HTTPException(
            status_code=500,
            detail=f"서버 오류가 발생했습니다: {str(e)}"
        )

@app.post("/api/auth/login", response_model=TokenResponse)
def login_user(login_data: UserLogin, db: Session = Depends(get_db)):
    """로그인"""
    # 이메일로 사용자 찾기
    user = db.query(models.User).filter(
        models.User.email == login_data.email
    ).first()
    
    if not user:
        raise HTTPException(status_code=401, detail="Incorrect email or password")
    
    # 비밀번호 확인
    if not verify_password(login_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Incorrect email or password")
    
    # 사용자 활성화 확인
    if not user.is_active:
        raise HTTPException(status_code=403, detail="User account is disabled")
    
    # JWT 토큰 생성
    access_token = create_access_token(data={"sub": user.id, "email": user.email})
    
    print(f"✅ 사용자 로그인: {user.email} ({user.username})")
    
    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        user=user
    )

@app.post("/api/rooms", response_model=ChatRoomResponse)
def create_room(
    room: ChatRoomCreate, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """새 채팅방 생성 (인증 필요)"""
    db_room = models.ChatRoom(
        user_id=current_user.id,
        title=room.title,
        learning_phase="home"  # 파인만 학습 초기 단계
    )
    db.add(db_room)
    db.commit()
    db.refresh(db_room)
    print(f"✅ 새 채팅방 생성: {db_room.title} (User: {current_user.username})")
    return db_room

@app.get("/api/rooms", response_model=List[ChatRoomResponse])
def get_rooms(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """현재 사용자의 모든 채팅방 조회 (인증 필요)"""
    rooms = db.query(models.ChatRoom).filter(
        models.ChatRoom.user_id == current_user.id
    ).order_by(models.ChatRoom.updated_at.desc()).all()
    return rooms

@app.get("/api/rooms/{room_id}/messages", response_model=List[MessageResponse])
def get_messages(
    room_id: str, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """특정 채팅방의 메시지 조회 (인증 필요, 본인 채팅방만)"""
    # 채팅방이 존재하고 현재 사용자의 것인지 확인
    room = db.query(models.ChatRoom).filter(
        models.ChatRoom.id == room_id
    ).first()
    
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    if room.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    messages = db.query(models.Message).filter(
        models.Message.room_id == room_id
    ).order_by(models.Message.created_at).all()
    return messages

@app.get("/api/auth/me", response_model=UserResponse)
def get_current_user_info(current_user: models.User = Depends(get_current_user)):
    """현재 로그인한 사용자 정보 조회"""
    return current_user

@app.delete("/api/rooms/{room_id}")
def delete_room(
    room_id: str, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """채팅방 삭제 (본인 채팅방만)"""
    room = db.query(models.ChatRoom).filter(models.ChatRoom.id == room_id).first()
    
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    # 본인 채팅방인지 확인
    if room.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    db.delete(room)
    db.commit()
    
    print(f"🗑️ 채팅방 삭제됨: {room_id} (User: {current_user.username})")
    
    return {"status": "ok", "message": "Room deleted"}

class DeleteRoomsRequest(BaseModel):
    room_ids: List[str]

# ========== Planner Pydantic 모델 ==========
class GoalCreate(BaseModel):
    title: str
    description: Optional[str] = None
    deadline: datetime

class GoalUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    deadline: Optional[datetime] = None
    is_completed: Optional[bool] = None

class GoalResponse(BaseModel):
    id: str
    user_id: str = Field(..., serialization_alias='userId')
    title: str
    description: Optional[str]
    deadline: datetime
    is_completed: bool = Field(..., serialization_alias='isCompleted')
    created_at: datetime = Field(..., serialization_alias='createdAt')

    class Config:
        from_attributes = True
        populate_by_name = True

class ScheduleCreate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    date: datetime
    title: str
    description: Optional[str] = None
    start_time: Optional[str] = Field(None, validation_alias='startTime')  # HH:MM
    end_time: Optional[str] = Field(None, validation_alias='endTime')    # HH:MM
    is_completed: Optional[bool] = Field(None, validation_alias='isCompleted')
    color: Optional[int] = None

class ScheduleUpdate(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    date: Optional[datetime] = None
    title: Optional[str] = None
    description: Optional[str] = None
    start_time: Optional[str] = Field(None, validation_alias='startTime')
    end_time: Optional[str] = Field(None, validation_alias='endTime')
    is_completed: Optional[bool] = Field(None, validation_alias='isCompleted')
    color: Optional[int] = None

class ScheduleResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True, populate_by_name=True)

    id: str
    user_id: str = Field(..., serialization_alias='userId')
    date: datetime
    title: str
    description: Optional[str]
    start_time: Optional[str] = Field(None, serialization_alias='startTime')
    end_time: Optional[str] = Field(None, serialization_alias='endTime')
    is_completed: bool = Field(..., serialization_alias='isCompleted')
    color: Optional[int]

class SubjectCreate(BaseModel):
    name: str
    credits: float
    grade: str  # A+, A, B+, etc.
    year: int
    semester: int

class SubjectUpdate(BaseModel):
    name: Optional[str] = None
    credits: Optional[float] = None
    grade: Optional[str] = None
    year: Optional[int] = None
    semester: Optional[int] = None

class SubjectResponse(BaseModel):
    id: str
    user_id: str
    name: str
    credits: float
    grade: str
    year: int
    semester: int

    class Config:
        from_attributes = True

# ========== Quiz 관련 Pydantic 모델 ==========
class QuizAnswerCreate(BaseModel):
    answer_text: str
    is_correct: bool
    answer_order: int

class QuizQuestionCreate(BaseModel):
    question_text: str
    question_type: str  # "multiple_choice" or "short_answer"
    question_order: int
    correct_answer: Optional[str] = None  # 서술형 정답
    answers: Optional[List[QuizAnswerCreate]] = None  # 4지선다 선택지
    image_data: Optional[str] = None  # Base64 인코딩된 이미지 데이터

class QuizCreate(BaseModel):
    quiz_name: str
    questions: List[QuizQuestionCreate]

class QuizAnswerResponse(BaseModel):
    id: str
    answer_text: str
    is_correct: bool
    answer_order: int

    class Config:
        from_attributes = True

class QuizQuestionResponse(BaseModel):
    id: str
    question_text: str
    question_type: str
    question_order: int
    correct_answer: Optional[str] = None
    image_data: Optional[str] = None
    answers: List[QuizAnswerResponse] = []

    class Config:
        from_attributes = True

class QuizResponse(BaseModel):
    id: str
    user_id: str
    quiz_name: str
    created_at: datetime
    updated_at: datetime
    questions: List[QuizQuestionResponse] = []

    class Config:
        from_attributes = True

class QuizUpdate(BaseModel):
    quiz_name: str

class ProgressSubmit(BaseModel):
    results: List[Dict]  # [{"question_id": "...", "is_correct": True/False}, ...]

class ProgressResponse(BaseModel):
    id: str
    user_id: str
    question_id: str
    last_attempted: datetime
    correct_count: int
    total_attempts: int
    next_review_date: Optional[datetime] = None

    class Config:
        from_attributes = True

@app.post("/api/rooms/delete-multiple")
def delete_multiple_rooms(
    request: DeleteRoomsRequest, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """여러 채팅방 한 번에 삭제 (본인 채팅방만)"""
    deleted_count = 0
    
    for room_id in request.room_ids:
        room = db.query(models.ChatRoom).filter(models.ChatRoom.id == room_id).first()
        if room and room.user_id == current_user.id:
            db.delete(room)
            deleted_count += 1
    
    db.commit()
    
    print(f"🗑️ {deleted_count}개 채팅방 삭제됨 (User: {current_user.username})")
    
    return {"status": "ok", "deleted_count": deleted_count}

@app.post("/api/rooms/{room_id}/messages")
def save_message(
    room_id: str, 
    message: MessageCreate, 
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """단순 메시지 저장 (AI 응답 없이, 본인 채팅방만)"""
    room = db.query(models.ChatRoom).filter(models.ChatRoom.id == room_id).first()
    
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    # 본인 채팅방인지 확인
    if room.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Access denied")
    
    # 메시지 저장
    db_message = models.Message(
        room_id=room_id,
        role=message.role,
        content=message.content,
        phase=message.phase
    )
    db.add(db_message)
    
    # 방 업데이트 시간 갱신
    room.updated_at = datetime.utcnow()
    db.commit()
    
    print(f"💾 메시지 저장됨 (단계: {message.phase}): {message.content[:50]}...")
    
    return {"status": "ok", "message_id": db_message.id}

# ========== 새로운 파인만 학습 엔드포인트 ==========
@app.post("/api/learning/transition", response_model=PhaseResponse)
async def transition_phase(
    request: PhaseTransitionRequest,
    db: Session = Depends(get_db)
):
    """학습 단계 전환"""
    room = db.query(models.ChatRoom).filter(
        models.ChatRoom.id == request.room_id
    ).first()
    
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    # 현재 단계 가져오기
    current_phase = LearningPhase(room.learning_phase or "home")
    
    # 다음 단계 결정
    next_phase = flow_manager.get_next_phase(current_phase, request.user_choice)
    
    # DB 업데이트
    room.learning_phase = next_phase.value
    db.commit()
    
    return PhaseResponse(
        current_phase=current_phase.value,
        next_phase=next_phase.value,
        instruction=flow_manager.get_phase_instruction(next_phase),
        title=flow_manager.get_phase_title(next_phase)
    )

@app.get("/api/learning/phase/{room_id}")
async def get_current_phase(room_id: str, db: Session = Depends(get_db)):
    """현재 학습 단계 조회"""
    room = db.query(models.ChatRoom).filter(
        models.ChatRoom.id == room_id
    ).first()
    
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    phase = LearningPhase(room.learning_phase or "home")
    
    return {
        "phase": phase.value,
        "instruction": flow_manager.get_phase_instruction(phase),
        "title": flow_manager.get_phase_title(phase),
        "can_go_back": flow_manager.can_go_back(phase)
    }

@app.post("/api/extract-keyword", response_model=KeywordExtractionResponse)
async def extract_keyword(request: KeywordExtractionRequest):
    """텍스트에서 핵심 키워드 추출"""
    keyword = await extract_concept_keyword(request.text)
    return KeywordExtractionResponse(
        original_text=request.text,
        extracted_keyword=keyword
    )

@app.post("/api/rooms/{room_id}/initialize-learning")
async def initialize_learning(
    room_id: str,
    request: InitializeLearningRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """채팅방의 학습 초기화 (PDF 뷰어에서 학습 시작 시 사용)"""
    room = db.query(models.ChatRoom).filter(
        models.ChatRoom.id == room_id,
        models.ChatRoom.user_id == current_user.id
    ).first()

    if not room:
        raise HTTPException(status_code=404, detail="Room not found")

    # PDF 경로: 선택한 텍스트 범위 그대로 저장 (채팅 경로와 구분)
    room.current_concept = request.concept
    room.original_question = request.concept  # PDF 선택 텍스트도 원본으로 저장 (맥락 보존)
    room.learning_phase = LearningPhase.KNOWLEDGE_CHECK.value
    db.commit()

    # 키워드 추출은 로그 표시용으로만 사용
    keyword = await extract_concept_keyword(request.concept)

    print(f"📄 PDF 학습 초기화: Room {room_id}")
    print(f"💾 선택된 텍스트 저장: {request.concept}")
    print(f"📝 원본 텍스트 저장: {request.concept}")
    print(f"🔍 참고 키워드: {keyword}")
    print(f"🔄 단계: KNOWLEDGE_CHECK")

    return {
        "room_id": room_id,
        "concept": request.concept,  # 원본 텍스트 반환
        "keyword": keyword,  # 키워드는 참고용
        "phase": LearningPhase.KNOWLEDGE_CHECK.value
    }

# ========== PDF 파일 관리 API ==========
@app.post("/api/pdf/upload", response_model=PDFFileResponse)
async def upload_pdf(
    file: UploadFile = File(...),
    folder_id: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """PDF 파일 업로드 및 DB 등록"""
    
    # 파일 형식 확인
    if not file.filename.endswith('.pdf'):
        raise HTTPException(status_code=400, detail="PDF 파일만 업로드 가능합니다")
    
    # 폴더 확인 (folder_id가 있는 경우)
    if folder_id:
        folder = db.query(models.Folder).filter(
            models.Folder.id == folder_id,
            models.Folder.user_id == current_user.id
        ).first()
        if not folder:
            raise HTTPException(status_code=404, detail="Folder not found")
    
    # 사용자별 업로드 디렉토리 생성
    user_upload_dir = f"uploads/{current_user.id}"
    os.makedirs(user_upload_dir, exist_ok=True)
    
    # 파일명 생성 (중복 방지)
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    safe_filename = f"{timestamp}_{file.filename}"
    file_path = os.path.join(user_upload_dir, safe_filename)
    
    file_size = 0
    chunk_size = 1024 * 1024  # 1MB
    
    try:
        # 파일 저장
        with open(file_path, "wb") as buffer:
            while chunk := await file.read(chunk_size):
                file_size += len(chunk)
                if file_size > 500 * 1024 * 1024:  # 500MB 제한
                    os.remove(file_path)
                    raise HTTPException(status_code=400, detail="파일 크기는 500MB 이하여야 합니다")
                buffer.write(chunk)
        
        # PDF 페이지 수 확인
        try:
            import PyPDF2
            with open(file_path, 'rb') as pdf_file:
                pdf_reader = PyPDF2.PdfReader(pdf_file)
                page_count = len(pdf_reader.pages)
        except:
            page_count = None
        
        # DB에 PDF 정보 저장
        new_pdf = models.PDFFile(
            user_id=current_user.id,
            folder_id=folder_id,
            filename=safe_filename,
            original_filename=file.filename,
            file_path=file_path,
            file_size=file_size,
            page_count=page_count
        )
        db.add(new_pdf)
        db.commit()
        db.refresh(new_pdf)
        
        # RAG 시스템에 PDF 추가 (user_id를 collection 이름으로 사용)
        rag_system.add_pdf_to_collection(
        user_id=current_user.id,
        pdf_id=new_pdf.id,
        pdf_path=file_path,
        filename=file.filename
    )
        
        print(f"✅ PDF 업로드 성공: {file.filename} (User: {current_user.username}, Size: {file_size} bytes)")
        return new_pdf
            
    except HTTPException:
        raise
    except Exception as e:
        # 오류 발생 시 파일 삭제
        if os.path.exists(file_path):
            os.remove(file_path)
        print(f"❌ PDF 업로드 오류: {e}")
        raise HTTPException(status_code=500, detail=f"업로드 실패: {str(e)}")

@app.get("/api/pdf/list", response_model=List[PDFFileResponse])
async def list_pdfs(
    folder_id: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """PDF 목록 조회 (폴더별 필터링 가능)"""
    query = db.query(models.PDFFile).filter(
        models.PDFFile.user_id == current_user.id
    )
    
    # folder_id가 "root" 또는 None이면 루트 폴더의 파일들만
    if folder_id == "root" or folder_id is None:
        query = query.filter(models.PDFFile.folder_id.is_(None))
    else:
        query = query.filter(models.PDFFile.folder_id == folder_id)
    
    pdfs = query.order_by(models.PDFFile.uploaded_at.desc()).all()
    return pdfs

@app.get("/api/pdf/{pdf_id}/usage")
async def check_pdf_usage(
    pdf_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """PDF 파일 사용 중인 채팅방 수 확인"""
    pdf = db.query(models.PDFFile).filter(
        models.PDFFile.id == pdf_id,
        models.PDFFile.user_id == current_user.id
    ).first()

    if not pdf:
        raise HTTPException(status_code=404, detail="PDF not found")

    # 해당 PDF를 사용하는 채팅방 개수 확인
    linked_rooms_count = db.query(models.ChatRoom).filter(
        models.ChatRoom.pdf_id == pdf_id,
        models.ChatRoom.user_id == current_user.id
    ).count()

    return {
        "pdf_id": pdf_id,
        "filename": pdf.original_filename,
        "linked_rooms_count": linked_rooms_count
    }

@app.delete("/api/pdf/{pdf_id}")
async def delete_pdf(
    pdf_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """PDF 파일 삭제 (연결된 채팅방 정리)"""
    pdf = db.query(models.PDFFile).filter(
        models.PDFFile.id == pdf_id,
        models.PDFFile.user_id == current_user.id
    ).first()

    if not pdf:
        raise HTTPException(status_code=404, detail="PDF not found")

    # 해당 PDF를 사용하는 채팅방 찾기
    linked_rooms = db.query(models.ChatRoom).filter(
        models.ChatRoom.pdf_id == pdf_id,
        models.ChatRoom.user_id == current_user.id
    ).all()

    linked_room_count = len(linked_rooms)

    # 연결된 채팅방들의 pdf_id를 null로 설정
    for room in linked_rooms:
        room.pdf_id = None

    # RAG 시스템에서 삭제
    rag_system.delete_pdf_from_collection(current_user.id, pdf_id)

    # 실제 파일 삭제
    if os.path.exists(pdf.file_path):
        os.remove(pdf.file_path)

    # DB에서 삭제
    db.delete(pdf)
    db.commit()

    print(f"✅ PDF 삭제: {pdf.original_filename} (연결된 채팅방: {linked_room_count}개)")
    return {
        "status": "success",
        "message": "PDF가 삭제되었습니다",
        "linked_rooms_count": linked_room_count
    }

@app.put("/api/pdf/{pdf_id}/move")
async def move_pdf(
    pdf_id: str,
    move_request: PDFMoveRequest,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """PDF를 다른 폴더로 이동"""
    pdf = db.query(models.PDFFile).filter(
        models.PDFFile.id == pdf_id,
        models.PDFFile.user_id == current_user.id
    ).first()
    
    if not pdf:
        raise HTTPException(status_code=404, detail="PDF not found")
    
    # 폴더 확인 (folder_id가 있는 경우)
    if move_request.folder_id:
        folder = db.query(models.Folder).filter(
            models.Folder.id == move_request.folder_id,
            models.Folder.user_id == current_user.id
        ).first()
        if not folder:
            raise HTTPException(status_code=404, detail="Target folder not found")
    
    pdf.folder_id = move_request.folder_id
    db.commit()
    db.refresh(pdf)
    
    print(f"✅ PDF 이동: {pdf.original_filename} → {move_request.folder_id or 'Root'}")
    return pdf

# ========== 폴더 관리 API ==========
@app.post("/api/folders/create", response_model=FolderResponse)
async def create_folder(
    folder: FolderCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """폴더 생성"""
    new_folder = models.Folder(
        user_id=current_user.id,
        name=folder.name
    )
    db.add(new_folder)
    db.commit()
    db.refresh(new_folder)
    
    print(f"✅ 폴더 생성: {folder.name} (User: {current_user.username})")
    return new_folder

@app.get("/api/folders/list", response_model=List[FolderResponse])
async def list_folders(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """사용자의 폴더 목록 조회"""
    folders = db.query(models.Folder).filter(
        models.Folder.user_id == current_user.id
    ).order_by(models.Folder.created_at.desc()).all()
    
    return folders

@app.delete("/api/folders/{folder_id}")
async def delete_folder(
    folder_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """폴더 삭제 (폴더 내 PDF는 루트로 이동)"""
    folder = db.query(models.Folder).filter(
        models.Folder.id == folder_id,
        models.Folder.user_id == current_user.id
    ).first()
    
    if not folder:
        raise HTTPException(status_code=404, detail="Folder not found")
    
    # 폴더 내 PDF들을 루트로 이동
    db.query(models.PDFFile).filter(
        models.PDFFile.folder_id == folder_id
    ).update({"folder_id": None})
    
    db.delete(folder)
    db.commit()
    
    print(f"✅ 폴더 삭제: {folder.name}")
    return {"status": "success", "message": "폴더가 삭제되었습니다"}

@app.put("/api/folders/{folder_id}")
async def rename_folder(
    folder_id: str,
    folder: FolderCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """폴더 이름 변경"""
    db_folder = db.query(models.Folder).filter(
        models.Folder.id == folder_id,
        models.Folder.user_id == current_user.id
    ).first()
    
    if not db_folder:
        raise HTTPException(status_code=404, detail="Folder not found")
    
    db_folder.name = folder.name
    db.commit()
    db.refresh(db_folder)
    
    return db_folder


@app.put("/api/rooms/{room_id}/link-pdf")
async def link_pdf_to_room(
    room_id: str,
    pdf_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """채팅방에 PDF 연결"""
    room = db.query(models.ChatRoom).filter(
        models.ChatRoom.id == room_id,
        models.ChatRoom.user_id == current_user.id
    ).first()
    
    if not room:
        raise HTTPException(status_code=404, detail="Room not found")
    
    # PDF 소유권 확인
    pdf = db.query(models.PDFFile).filter(
        models.PDFFile.id == pdf_id,
        models.PDFFile.user_id == current_user.id
    ).first()
    
    if not pdf:
        raise HTTPException(status_code=404, detail="PDF not found")
    
    room.pdf_id = pdf_id
    db.commit()
    
    print(f"✅ PDF 연결: Room {room_id} ← PDF {pdf.original_filename}")
    return {"status": "success", "room_id": room_id, "pdf_id": pdf_id}


# ========== 수정된 WebSocket (파인만 통합) ==========
@app.websocket("/ws/chat/{room_id}")
async def websocket_endpoint_with_feynman(
    websocket: WebSocket, 
    room_id: str
):
    await websocket.accept()
    print(f"✅ WebSocket 연결됨 (Room: {room_id})")

    db = SessionLocal()
    
    try:
        room = db.query(models.ChatRoom).filter(models.ChatRoom.id == room_id).first()
        if not room:
            await websocket.send_json({"error": "Room not found"})
            await websocket.close()
            return
        
        while True:
            data = await websocket.receive_text()
            print(f"📥 받은 메시지 (Room {room_id}): {data}")
            
            message_data = json.loads(data)
            
            # 메시지 타입 확인
            msg_type = message_data.get("type", "message")
            
            if msg_type == "phase_transition":
                # 단계 전환 요청
                user_choice = message_data.get("choice")
                current_phase = LearningPhase(room.learning_phase or "home")
                next_phase = flow_manager.get_next_phase(current_phase, user_choice)
                
                room.learning_phase = next_phase.value
                db.commit()
                
                await websocket.send_json({
                    "type": "phase_changed",
                    "phase": next_phase.value,
                    "instruction": flow_manager.get_phase_instruction(next_phase),
                    "title": flow_manager.get_phase_title(next_phase)
                })
                continue
            
            # 일반 메시지 처리
            try:
                user_message = message_data["message"]
            except KeyError as e:
                await websocket.send_json({
                    "type": "error",
                    "content": "Invalid message format"
                })
                continue

            # 현재 학습 단계 확인 (RAG 쿼리 생성에 필요)
            current_phase = LearningPhase(room.learning_phase or "home")

            # RAG 컨텍스트 검색 (채팅방에 연결된 PDF에서만)
            rag_context = ""
            pdf_has_content = False  # PDF에 관련 내용이 있는지 추적
            if room.pdf_id:
                # 채팅방에 PDF가 연결되어 있으면
                if rag_system.has_pdf(room.user_id, room.pdf_id):
                    # 학습 단계별 최적화된 쿼리 생성
                    rag_query = get_rag_query_for_phase(
                        phase=current_phase,
                        concept=room.current_concept or "",
                        message=user_message,
                        original_question=getattr(room, 'original_question', None)
                    )
                    print(f"🔍 RAG 검색 쿼리 (단계: {current_phase.value}): '{rag_query}'")

                    contexts = rag_system.search_by_pdf(
                        user_id=room.user_id,
                        pdf_id=room.pdf_id,
                        query=rag_query,  # 최적화된 쿼리 사용
                        n_results=5
                    )
                    if contexts:
                        pdf_has_content = True
                        rag_context = "\n\n**PDF 자료 (반드시 이 내용을 기반으로 답변해야 합니다):**\n"
                        for ctx in contexts:
                            # 전체 내용 포함 (잘리지 않도록)
                            rag_context += f"[{ctx['filename']} - Page {ctx['page']}]\n{ctx['content']}\n\n---\n\n"
                        print(f"📚 RAG 컨텍스트 추가됨 ({len(contexts)}개, PDF: {room.pdf_id})")
                    else:
                        print(f"⚠️ PDF에 관련 내용을 찾지 못함 (PDF: {room.pdf_id})")
            
            # 사용자 메시지 저장 (단계 정보 포함)
            user_msg = models.Message(
                room_id=room_id,
                role="user",
                content=user_message,
                phase=current_phase.value if hasattr(models.Message, 'phase') else None,
                is_explanation=(current_phase in [
                    LearningPhase.FIRST_EXPLANATION,
                    LearningPhase.SECOND_EXPLANATION
                ]) if hasattr(models.Message, 'is_explanation') else None
            )
            db.add(user_msg)
            db.commit()
            print(f"💾 사용자 메시지 저장됨 (단계: {current_phase.value})")
            
            if current_phase == LearningPhase.HOME:
                # 키워드 추출
                concept_keyword = await extract_concept_keyword(user_message)

                # 채팅 경로: 키워드 + 원본 질문 모두 저장
                room.current_concept = concept_keyword
                room.original_question = user_message  # 원본 질문 보존 (맥락 보존)
                room.learning_phase = LearningPhase.KNOWLEDGE_CHECK.value
                db.commit()

                print(f"💬 채팅 메시지: '{user_message}'")
                print(f"💾 추출된 키워드 저장: '{concept_keyword}'")
                print(f"📝 원본 질문 저장: '{user_message}'")
                print(f"🔄 단계 전환: HOME → KNOWLEDGE_CHECK")
    
            # AI 응답 없이 바로 단계 전환 알림
                await websocket.send_json({
                    "type": "phase_changed",
                    "phase": LearningPhase.KNOWLEDGE_CHECK.value,
                    "instruction": flow_manager.get_phase_instruction(LearningPhase.KNOWLEDGE_CHECK),
                    "title": flow_manager.get_phase_title(LearningPhase.KNOWLEDGE_CHECK)
                })
    
                # 단순 안내 메시지만 전송
                simple_response = f"'{concept_keyword}'에 대해 학습하시는군요! 이 개념에 대해 얼마나 알고 계신가요?"
    
                ai_msg = models.Message(
                    room_id=room_id,
                    role="assistant",
                    content=simple_response,
                    phase=LearningPhase.KNOWLEDGE_CHECK.value if hasattr(models.Message, 'phase') else None
                )
                db.add(ai_msg)
                room.updated_at = datetime.utcnow()
                db.commit()
    
                await websocket.send_json({
                    "type": "stream",
                    "content": simple_response,
                    "phase": LearningPhase.KNOWLEDGE_CHECK.value
                })
    
                await websocket.send_json({
                    "type": "complete",
                    "phase": LearningPhase.KNOWLEDGE_CHECK.value
                })
    
                print("✅ KNOWLEDGE_CHECK 단계로 전환 완료")
                continue  # Ollama 호출 없이 다음 메시지 대기


            # 사용자 설명 분석 (설명 단계인 경우)
            analysis = None
            if current_phase in [LearningPhase.FIRST_EXPLANATION, LearningPhase.SECOND_EXPLANATION]:
                analysis = evaluator.analyze_explanation(user_message)
                print(f"📊 설명 분석 완료")
            
            # 컨텍스트 준비
            context = {
                "concept": room.current_concept if hasattr(room, 'current_concept') else None,
                "original_question": getattr(room, 'original_question', None),  # 원본 질문 (맥락 정보)
                "knowledge_level": room.knowledge_level if hasattr(room, 'knowledge_level') else 0,
                "analysis": analysis,
                "phase": current_phase.value
            }
            
            # 파인만 프롬프트 가져오기
            system_prompt = feynman_engine.get_prompt_for_phase(current_phase, context)
            
            # Ollama API 호출
            ai_response = ""
            try:
                async with httpx.AsyncClient() as client:
                    print("🤖 Ollama 요청 중 (파인만 모드)...")

                    # Ollama에 시스템 프롬프트 포함
                    if pdf_has_content:
                        # PDF에 관련 내용이 있는 경우: PDF 기반으로만 답변하도록 강제
                        full_prompt = f"""{system_prompt}

{rag_context}

**🔴 중요 지시사항 (반드시 준수):**
1. 위에 제공된 PDF 자료의 내용만을 기반으로 답변하세요
2. PDF 자료에 있는 개념, 용어, 설명, 과정을 그대로 사용하세요
3. PDF 자료의 내용과 다르게 설명하지 마세요
4. 당신의 학습된 지식이 PDF 내용과 다르더라도, PDF 내용을 우선하세요
5. PDF에 나온 그대로의 표현과 설명 방식을 따르세요

사용자: {user_message}

AI:"""
                    elif room.pdf_id:
                        # PDF는 등록되어 있지만 관련 내용을 찾지 못한 경우
                        full_prompt = f"""{system_prompt}

**알림:** 등록된 PDF 자료에서 '{user_message}'와 관련된 내용을 찾을 수 없습니다.
일반적인 지식을 바탕으로 답변하겠습니다.

사용자: {user_message}

AI:"""
                    else:
                        # PDF가 등록되지 않은 경우: 일반 지식으로 답변
                        full_prompt = f"{system_prompt}\n\n사용자: {user_message}\n\nAI:"

                    print(f"📝 프롬프트 길이: {len(full_prompt)} 문자")
                    print(f"📝 PDF 컨텍스트 사용: {pdf_has_content}")
                    print(f"📝 프롬프트 미리보기:\n{full_prompt[:500]}...")
                    
                    async with client.stream(
                        "POST",
                        "http://localhost:11434/api/generate",
                        json={
                            "model": "llama3.1:8b",
                            "prompt": full_prompt,
                            "stream": True
                        },
                        timeout=httpx.Timeout(60.0, connect=10.0)
                    ) as response:
                        
                        print(f"📡 Ollama 응답 상태: {response.status_code}")
                        
                        if response.status_code != 200:
                            await websocket.send_json({
                                "type": "error",
                                "content": f"Ollama error: {response.status_code}"
                            })
                            continue
                        
                        async for line in response.aiter_lines():
                            if line.strip():
                                try:
                                    chunk_data = json.loads(line)
                                    
                                    if "response" in chunk_data:
                                        chunk = chunk_data["response"]
                                        ai_response += chunk
                                        
                                        await websocket.send_json({
                                            "type": "stream",
                                            "content": chunk,
                                            "phase": current_phase.value
                                        })
                                    
                                    if chunk_data.get("done", False):
                                        break
                                        
                                except json.JSONDecodeError:
                                    continue
                
                # AI 응답 저장
                ai_msg = models.Message(
                    room_id=room_id,
                    role="assistant",
                    content=ai_response,
                    phase=current_phase.value if hasattr(models.Message, 'phase') else None
                )
                db.add(ai_msg)
                room.updated_at = datetime.utcnow()
                db.commit()
                print(f"💾 AI 응답 저장됨 (단계: {current_phase.value})")
                
                # 평가 단계인 경우 평가 결과 저장
                if current_phase == LearningPhase.EVALUATION and analysis:
                    if hasattr(models, 'LearningEvaluation'):
                        evaluation = models.LearningEvaluation(
                            room_id=room_id,
                            message_id=user_msg.id,
                            strengths=analysis.get("strengths", []),
                            weaknesses=analysis.get("weaknesses", []),
                            suggestions=analysis.get("suggestions", [])
                        )
                        db.add(evaluation)
                        db.commit()
                        print(f"📊 평가 결과 저장됨")
                
                await websocket.send_json({
                    "type": "complete",
                    "phase": current_phase.value
                })
                print("✉️ 완료 신호 전송")
                
            except Exception as e:
                import traceback
                error_detail = traceback.format_exc()
                print(f"❌ 처리 오류 발생!")
                print(f"❌ 에러 타입: {type(e).__name__}")
                print(f"❌ 에러 메시지: {str(e)}")
                print(f"❌ 상세 스택:")
                print(error_detail)
    
                await websocket.send_json({
                    "type": "error",
                    "content": f"Error: {str(e)}"
                })
                
    except WebSocketDisconnect:
        print(f"🔌 WebSocket 연결 끊김 (Room: {room_id})")
    except Exception as e:
        print(f"❌ WebSocket 오류: {e}")
    finally:
        db.close()

# ========== Planner API - Goals ==========
@app.get("/api/planner/goals", response_model=List[GoalResponse])
def get_goals(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """사용자의 모든 목표 가져오기"""
    goals = db.query(models.Goal).filter(
        models.Goal.user_id == current_user.id
    ).order_by(models.Goal.deadline).all()

    return goals

@app.post("/api/planner/goals", response_model=GoalResponse)
def create_goal(
    goal_data: GoalCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """새 목표 생성"""
    import uuid
    goal = models.Goal(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        **goal_data.dict()
    )
    db.add(goal)
    db.commit()
    db.refresh(goal)

    print(f"🎯 목표 생성됨: {goal.title} (User: {current_user.username})")
    return goal

@app.put("/api/planner/goals/{goal_id}", response_model=GoalResponse)
def update_goal(
    goal_id: str,
    goal_update: GoalUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """목표 수정"""
    goal = db.query(models.Goal).filter(
        models.Goal.id == goal_id,
        models.Goal.user_id == current_user.id
    ).first()

    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")

    # 제공된 필드만 업데이트
    update_data = goal_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(goal, key, value)

    db.commit()
    db.refresh(goal)

    print(f"✏️ 목표 수정됨: {goal.title}")
    return goal

@app.delete("/api/planner/goals/{goal_id}")
def delete_goal(
    goal_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """목표 삭제"""
    goal = db.query(models.Goal).filter(
        models.Goal.id == goal_id,
        models.Goal.user_id == current_user.id
    ).first()

    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")

    db.delete(goal)
    db.commit()

    print(f"🗑️ 목표 삭제됨: {goal.title}")
    return {"status": "ok", "message": "Goal deleted"}

@app.patch("/api/planner/goals/{goal_id}/toggle")
def toggle_goal_completion(
    goal_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """목표 완료 상태 토글"""
    goal = db.query(models.Goal).filter(
        models.Goal.id == goal_id,
        models.Goal.user_id == current_user.id
    ).first()

    if not goal:
        raise HTTPException(status_code=404, detail="Goal not found")

    goal.is_completed = not goal.is_completed
    db.commit()

    print(f"✅ 목표 상태 변경: {goal.title} -> {goal.is_completed}")
    return {"status": "ok", "is_completed": goal.is_completed}

# ========== Planner API - Schedules ==========
@app.get("/api/planner/schedules", response_model=List[ScheduleResponse], response_model_by_alias=True)
def get_schedules(
    date: Optional[str] = None,  # YYYY-MM-DD 형식
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """사용자의 일정 가져오기 (날짜 필터 옵션)"""
    query = db.query(models.Schedule).filter(
        models.Schedule.user_id == current_user.id
    )

    # 날짜 필터가 있으면 적용
    if date:
        try:
            filter_date = datetime.fromisoformat(date)
            # 해당 날짜의 시작과 끝
            start_of_day = filter_date.replace(hour=0, minute=0, second=0, microsecond=0)
            end_of_day = filter_date.replace(hour=23, minute=59, second=59, microsecond=999999)

            query = query.filter(
                models.Schedule.date >= start_of_day,
                models.Schedule.date <= end_of_day
            )
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD")

    schedules = query.order_by(models.Schedule.date).all()
    return schedules

@app.post("/api/planner/schedules", response_model=ScheduleResponse, response_model_by_alias=True)
def create_schedule(
    schedule_data: ScheduleCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """새 일정 생성"""
    import uuid
    schedule = models.Schedule(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        **schedule_data.dict()
    )
    db.add(schedule)
    db.commit()
    db.refresh(schedule)

    print(f"📅 일정 생성됨: {schedule.title} (User: {current_user.username})")
    return schedule

@app.put("/api/planner/schedules/{schedule_id}", response_model=ScheduleResponse, response_model_by_alias=True)
def update_schedule(
    schedule_id: str,
    schedule_update: ScheduleUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """일정 수정"""
    schedule = db.query(models.Schedule).filter(
        models.Schedule.id == schedule_id,
        models.Schedule.user_id == current_user.id
    ).first()

    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")

    update_data = schedule_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(schedule, key, value)

    db.commit()
    db.refresh(schedule)

    print(f"✏️ 일정 수정됨: {schedule.title}")
    return schedule

@app.delete("/api/planner/schedules/{schedule_id}")
def delete_schedule(
    schedule_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """일정 삭제"""
    schedule = db.query(models.Schedule).filter(
        models.Schedule.id == schedule_id,
        models.Schedule.user_id == current_user.id
    ).first()

    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")

    db.delete(schedule)
    db.commit()

    print(f"🗑️ 일정 삭제됨: {schedule.title}")
    return {"status": "ok", "message": "Schedule deleted"}

@app.patch("/api/planner/schedules/{schedule_id}/toggle")
def toggle_schedule_completion(
    schedule_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """일정 완료 상태 토글"""
    schedule = db.query(models.Schedule).filter(
        models.Schedule.id == schedule_id,
        models.Schedule.user_id == current_user.id
    ).first()

    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")

    schedule.is_completed = not schedule.is_completed
    db.commit()

    print(f"✅ 일정 상태 변경: {schedule.title} -> {schedule.is_completed}")
    return {"status": "ok", "is_completed": schedule.is_completed}

# ========== Planner API - Subjects ==========
@app.get("/api/planner/subjects", response_model=List[SubjectResponse])
def get_subjects(
    year: Optional[int] = None,
    semester: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """사용자의 과목 가져오기 (학년/학기 필터 옵션)"""
    query = db.query(models.Subject).filter(
        models.Subject.user_id == current_user.id
    )

    if year:
        query = query.filter(models.Subject.year == year)
    if semester:
        query = query.filter(models.Subject.semester == semester)

    subjects = query.order_by(
        models.Subject.year,
        models.Subject.semester,
        models.Subject.name
    ).all()

    return subjects

@app.post("/api/planner/subjects", response_model=SubjectResponse)
def create_subject(
    subject_data: SubjectCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """새 과목 생성"""
    import uuid
    subject = models.Subject(
        id=str(uuid.uuid4()),
        user_id=current_user.id,
        **subject_data.dict()
    )
    db.add(subject)
    db.commit()
    db.refresh(subject)

    print(f"📚 과목 생성됨: {subject.name} (User: {current_user.username})")
    return subject

@app.put("/api/planner/subjects/{subject_id}", response_model=SubjectResponse)
def update_subject(
    subject_id: str,
    subject_update: SubjectUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """과목 수정"""
    subject = db.query(models.Subject).filter(
        models.Subject.id == subject_id,
        models.Subject.user_id == current_user.id
    ).first()

    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    update_data = subject_update.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(subject, key, value)

    db.commit()
    db.refresh(subject)

    print(f"✏️ 과목 수정됨: {subject.name}")
    return subject

@app.delete("/api/planner/subjects/{subject_id}")
def delete_subject(
    subject_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """과목 삭제"""
    subject = db.query(models.Subject).filter(
        models.Subject.id == subject_id,
        models.Subject.user_id == current_user.id
    ).first()

    if not subject:
        raise HTTPException(status_code=404, detail="Subject not found")

    db.delete(subject)
    db.commit()

    print(f"🗑️ 과목 삭제됨: {subject.name}")
    return {"status": "ok", "message": "Subject deleted"}

# ========== Quiz 관련 API 엔드포인트 ==========

@app.get("/api/users/{user_id}/quizzes", response_model=List[QuizResponse])
async def get_user_quizzes(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """사용자의 모든 퀴즈 조회"""
    if current_user.id != user_id:
        raise HTTPException(status_code=403, detail="권한이 없습니다")

    quizzes = db.query(models.Quiz).filter(
        models.Quiz.user_id == user_id
    ).order_by(models.Quiz.created_at.desc()).all()

    print(f"📚 {current_user.username}의 퀴즈 {len(quizzes)}개 조회")
    return quizzes

@app.post("/api/quizzes", response_model=QuizResponse)
async def create_quiz(
    quiz_data: QuizCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """퀴즈 생성 (수동 또는 AI 생성 후 저장)"""
    new_quiz = models.Quiz(
        quiz_name=quiz_data.quiz_name,
        user_id=current_user.id
    )
    db.add(new_quiz)
    db.flush()

    # 질문 추가
    for q_data in quiz_data.questions:
        new_question = models.QuizQuestion(
            quiz_id=new_quiz.id,
            question_text=q_data.question_text,
            question_type=q_data.question_type,
            question_order=q_data.question_order,
            correct_answer=q_data.correct_answer,
            image_data=q_data.image_data
        )
        db.add(new_question)
        db.flush()

        # 4지선다 선택지 추가
        if q_data.question_type == "multiple_choice" and q_data.answers:
            for a_data in q_data.answers:
                new_answer = models.QuizAnswer(
                    question_id=new_question.id,
                    answer_text=a_data.answer_text,
                    is_correct=a_data.is_correct,
                    answer_order=a_data.answer_order
                )
                db.add(new_answer)

    db.commit()
    db.refresh(new_quiz)

    print(f"✅ 퀴즈 생성됨: {new_quiz.quiz_name} ({len(quiz_data.questions)}문제)")
    return new_quiz

@app.delete("/api/quizzes/{quiz_id}")
async def delete_quiz(
    quiz_id: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """퀴즈 삭제"""
    quiz = db.query(models.Quiz).filter(models.Quiz.id == quiz_id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="퀴즈를 찾을 수 없습니다")
    if quiz.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="권한이 없습니다")

    quiz_name = quiz.quiz_name
    db.delete(quiz)
    db.commit()

    print(f"🗑️ 퀴즈 삭제됨: {quiz_name}")
    return {"message": "퀴즈가 삭제되었습니다"}

@app.put("/api/quizzes/{quiz_id}", response_model=QuizResponse)
async def update_quiz(
    quiz_id: str,
    quiz_update: QuizUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """퀴즈 제목 수정"""
    quiz = db.query(models.Quiz).filter(models.Quiz.id == quiz_id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="퀴즈를 찾을 수 없습니다")
    if quiz.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="권한이 없습니다")

    # 제목 업데이트
    quiz.quiz_name = quiz_update.quiz_name
    quiz.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(quiz)

    print(f"✏️ 퀴즈 제목 수정됨: {quiz.quiz_name}")
    return quiz

@app.post("/api/quizzes/generate-from-pdf")
async def generate_quiz_from_pdf(
    file: UploadFile = File(...),
    num_questions: int = Form(5),
    question_types: str = Form("mixed"),
    current_user: Optional[models.User] = Depends(get_current_user)
):
    """PDF에서 AI 퀴즈 생성 (저장하지 않고 반환만)"""
    try:
        if not file.filename.endswith('.pdf'):
            raise HTTPException(status_code=400, detail="PDF 파일만 업로드 가능합니다")

        # PDF 읽기
        contents = await file.read()
        pdf_file = BytesIO(contents)
        pdf_file.name = file.filename

        # 텍스트 추출
        text = extract_text_from_pdf(pdf_file)
        if not text:
            raise HTTPException(status_code=400, detail="PDF에서 텍스트를 추출할 수 없습니다")

        # 텍스트 길이 제한 (5000 토큰 = 20000자)
        text = truncate_text(text, max_tokens=5000)

        # AI 퀴즈 생성
        questions = generate_quiz_from_text(
            text=text,
            num_questions=num_questions,
            question_types=question_types
        )

        if not questions:
            raise HTTPException(status_code=500, detail="AI 퀴즈 생성에 실패했습니다")

        print(f"🤖 AI 퀴즈 생성 완료: {file.filename} → {len(questions)}문제")
        return {
            "success": True,
            "filename": file.filename,
            "questions": questions,
            "message": f"{len(questions)}개의 문제가 생성되었습니다"
        }

    except HTTPException:
        raise
    except Exception as e:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"퀴즈 생성 중 오류 발생: {str(e)}")

# ========== Progress (Spaced Repetition) API ==========

@app.post("/api/progress")
async def submit_progress(
    progress_data: ProgressSubmit,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """퀴즈 진행 상황 기록 (간격 반복 학습)"""
    for result in progress_data.results:
        question_id = result["question_id"]
        is_correct = result["is_correct"]

        # 기존 진행 상황 조회
        progress = db.query(models.UserProgress).filter(
            models.UserProgress.user_id == current_user.id,
            models.UserProgress.question_id == question_id
        ).first()

        if not progress:
            # 첫 시도 -> 1일 후 복습
            progress = models.UserProgress(
                user_id=current_user.id,
                question_id=question_id,
                total_attempts=1,
                correct_count=1 if is_correct else 0,
                next_review_date=datetime.utcnow() + timedelta(days=1),
                last_attempted=datetime.utcnow()
            )
            db.add(progress)
        else:
            # 재시도 -> 간격 조정
            progress.total_attempts += 1
            progress.last_attempted = datetime.utcnow()

            if is_correct:
                progress.correct_count += 1
                # 정답 -> 간격 2배 증가 (최대 30일)
                current_interval = 1 if not progress.next_review_date else \
                    (progress.next_review_date - progress.last_attempted).days
                new_interval = min(current_interval * 2, 30)
                progress.next_review_date = datetime.utcnow() + timedelta(days=new_interval)
            else:
                # 오답 -> 간격 1일로 리셋
                progress.next_review_date = datetime.utcnow() + timedelta(days=1)

    db.commit()
    print(f"📊 {current_user.username} 진행 상황 저장: {len(progress_data.results)}문제")
    return {"message": "진행 상황이 저장되었습니다"}

@app.get("/api/users/{user_id}/progress", response_model=List[ProgressResponse])
async def get_user_progress(
    user_id: str,
    review_due: bool = False,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_user)
):
    """사용자 학습 진척도 조회"""
    if current_user.id != user_id:
        raise HTTPException(status_code=403, detail="권한이 없습니다")

    query = db.query(models.UserProgress).filter(
        models.UserProgress.user_id == user_id
    )

    # 복습 기한 도래한 문제만 필터링
    if review_due:
        query = query.filter(
            models.UserProgress.next_review_date <= datetime.utcnow()
        )

    progress_list = query.all()
    print(f"📈 {current_user.username} 진척도 조회: {len(progress_list)}문제")
    return progress_list

if __name__ == "__main__":
    import uvicorn
    print("="*50)
    print(f"🚀 파인만 학습법 서버 시작")
    print(f"📍 Local IP: http://{LOCAL_IP}:8000")
    print(f"📍 Localhost: http://localhost:8000")
    print(f"🧪 Ollama 테스트: http://localhost:8000/test-ollama")
    print(f"📚 API 문서: http://localhost:8000/docs")
    print("="*50)
    print("📌 학습 API:")
    print(f"  - 현재 단계: GET /api/learning/phase/{{room_id}}")
    print(f"  - 단계 전환: POST /api/learning/transition")
    print("="*50)
    
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")