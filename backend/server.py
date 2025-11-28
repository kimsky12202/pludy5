from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi import Header
from sqlalchemy.orm import Session
from typing import List, Optional, Dict
from database import engine, get_db, SessionLocal
from pydantic import BaseModel
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
from fastapi import File, UploadFile
from rag_system import rag_system
from fastapi.staticfiles import StaticFiles

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
    
    extraction_prompt = f"""다음 질문에서 학습하고자 하는 핵심 개념/키워드만 추출하세요.
질문: {user_message}

규칙:
- 2-3단어 이내의 핵심 개념만 추출
- "에 대해", "알려줘", "설명해줘" 등은 제외
- 명사형으로 추출
- 한 줄로만 답변

예시:
질문: "자료구조에 대해서 알려줘" → 자료구조
질문: "머신러닝 알고리즘 설명해줘" → 머신러닝 알고리즘
질문: "양자역학이 뭐야?" → 양자역학

키워드:"""

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

    # 원본 텍스트를 그대로 저장 (채팅 방식과 동일)
    room.current_concept = request.concept
    room.learning_phase = LearningPhase.KNOWLEDGE_CHECK.value
    db.commit()

    # 키워드 추출은 내부적으로만 사용 (표시용)
    keyword = await extract_concept_keyword(request.concept)

    print(f"📚 학습 초기화: Room {room_id}")
    print(f"   원본 텍스트: {request.concept}")
    print(f"   추출된 키워드: {keyword}")
    print(f"   단계: KNOWLEDGE_CHECK")

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
                if file_size > 50 * 1024 * 1024:  # 50MB 제한
                    os.remove(file_path)
                    raise HTTPException(status_code=400, detail="파일 크기는 50MB 이하여야 합니다")
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

            # RAG 컨텍스트 검색 (채팅방에 연결된 PDF에서만)
            rag_context = ""
            if room.pdf_id:
                # 채팅방에 PDF가 연결되어 있으면
                if rag_system.has_pdf(room.user_id, room.pdf_id):
                    contexts = rag_system.search_by_pdf(
                        user_id=room.user_id,
                        pdf_id=room.pdf_id,
                        query=user_message,
                        n_results=5
                    )
                    if contexts:
                        rag_context = "\n\n**참고 자료:**\n"
                        for ctx in contexts:
                            rag_context += f"[{ctx['filename']} - Page {ctx['page']}] {ctx['content'][:200]}...\n\n"
                        print(f"📚 RAG 컨텍스트 추가됨 ({len(contexts)}개, PDF: {room.pdf_id})")
            
            # 현재 학습 단계 확인
            current_phase = LearningPhase(room.learning_phase or "home")
            
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

                # 개념 저장
                room.current_concept = user_message
                room.learning_phase = LearningPhase.KNOWLEDGE_CHECK.value
                db.commit()

                print(f"💾 원본 텍스트 저장: '{user_message}'")
                print(f"🔍 추출된 키워드: '{concept_keyword}'")
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
                    if rag_context:
                        full_prompt = f"{system_prompt}\n\n{rag_context}\n\n사용자: {user_message}\n\nAI:"
                    else:
                        full_prompt = f"{system_prompt}\n\n사용자: {user_message}\n\nAI:"
                    print(f"📝 프롬프트 길이: {len(full_prompt)} 문자")
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