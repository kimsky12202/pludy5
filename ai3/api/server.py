# backend/server.py
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, Depends, HTTPException, status, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timedelta
import json

# 로컬 모듈
import models
import schemas
import auth
from database import engine, get_db
from pdf_utils import extract_text_from_pdf, truncate_text
from quiz_generator import generate_quiz_from_text

# 데이터베이스 테이블 생성
models.Base.metadata.create_all(bind=engine)

# FastAPI 앱 생성
app = FastAPI(
    title="Feynman Learning & Quiz API",
    description="파인만 학습법 기반 AI 튜터 + 퀴즈 시스템",
    version="2.0.0"
)

# CORS 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# WebSocket 연결 관리
class ConnectionManager:
    def __init__(self):
        self.active_connections: dict[int, WebSocket] = {}

    async def connect(self, websocket: WebSocket, room_id: int):
        await websocket.accept()
        self.active_connections[room_id] = websocket

    def disconnect(self, room_id: int):
        if room_id in self.active_connections:
            del self.active_connections[room_id]

    async def send_message(self, message: str, room_id: int):
        if room_id in self.active_connections:
            await self.active_connections[room_id].send_text(message)

manager = ConnectionManager()

# ===== 인증 엔드포인트 =====

@app.post("/api/auth/register", response_model=schemas.AuthToken)
async def register(user_data: schemas.UserCreate, db: Session = Depends(get_db)):
    """회원가입"""
    existing_user = db.query(models.User).filter(
        models.User.email == user_data.email
    ).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="이미 사용 중인 이메일입니다")
    
    existing_username = db.query(models.User).filter(
        models.User.username == user_data.username
    ).first()
    if existing_username:
        raise HTTPException(status_code=400, detail="이미 사용 중인 사용자명입니다")
    
    hashed_password = auth.get_password_hash(user_data.password)
    new_user = models.User(
        username=user_data.username,
        email=user_data.email,
        hashed_password=hashed_password
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    token = auth.create_access_token({"user_id": new_user.id})
    
    return {
        "token": token,
        "user_id": new_user.id,
        "username": new_user.username,
        "email": new_user.email
    }

@app.post("/api/auth/login", response_model=schemas.AuthToken)
async def login(user_data: schemas.UserLogin, db: Session = Depends(get_db)):
    """로그인"""
    user = db.query(models.User).filter(
        models.User.email == user_data.email
    ).first()
    
    if not user or not auth.verify_password(user_data.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="이메일 또는 비밀번호가 올바르지 않습니다")
    
    token = auth.create_access_token({"user_id": user.id})
    
    return {
        "token": token,
        "user_id": user.id,
        "username": user.username,
        "email": user.email
    }

# [추가] 계정 삭제 (회원 탈퇴)
@app.delete("/api/auth/me")
async def delete_account(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    """현재 로그인한 사용자 계정 삭제"""
    user = db.query(models.User).filter(models.User.id == current_user.id).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="사용자를 찾을 수 없습니다")
    
    db.delete(user)
    db.commit()
    
    return {"message": "계정이 성공적으로 삭제되었습니다"}

# ===== 채팅방 엔드포인트 =====

@app.post("/api/rooms", response_model=schemas.ChatRoomResponse)
async def create_room(
    room_data: schemas.ChatRoomCreate,
    db: Session = Depends(get_db),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    new_room = models.ChatRoom(
        concept=room_data.concept,
        current_phase=room_data.current_phase,
        user_id=current_user.id if current_user else None
    )
    db.add(new_room)
    db.commit()
    db.refresh(new_room)
    return new_room

@app.get("/api/rooms/{room_id}", response_model=schemas.ChatRoomResponse)
async def get_room(room_id: int, db: Session = Depends(get_db)):
    room = db.query(models.ChatRoom).filter(models.ChatRoom.id == room_id).first()
    if not room:
        raise HTTPException(status_code=404, detail="채팅방을 찾을 수 없습니다")
    return room

@app.get("/api/rooms/{room_id}/messages", response_model=List[schemas.MessageResponse])
async def get_messages(room_id: int, db: Session = Depends(get_db)):
    messages = db.query(models.Message).filter(
        models.Message.room_id == room_id
    ).order_by(models.Message.created_at).all()
    return messages

# ===== WebSocket 엔드포인트 =====

@app.websocket("/ws/{room_id}")
async def websocket_endpoint(websocket: WebSocket, room_id: int, db: Session = Depends(get_db)):
    await manager.connect(websocket, room_id)
    try:
        while True:
            data = await websocket.receive_text()
            message_data = json.loads(data)
            
            new_message = models.Message(
                room_id=room_id,
                content=message_data["content"],
                sender=message_data["sender"],
                phase=message_data.get("phase")
            )
            db.add(new_message)
            db.commit()
            
            if message_data["sender"] == "user":
                ai_response = f"AI 응답: {message_data['content']}"
                ai_message = models.Message(
                    room_id=room_id,
                    content=ai_response,
                    sender="ai",
                    phase=message_data.get("phase")
                )
                db.add(ai_message)
                db.commit()
                
                await manager.send_message(
                    json.dumps({
                        "content": ai_response,
                        "sender": "ai",
                        "phase": message_data.get("phase")
                    }),
                    room_id
                )
    except WebSocketDisconnect:
        manager.disconnect(room_id)

# ===== 퀴즈 엔드포인트 =====

@app.get("/api/users/{user_id}/quizzes", response_model=List[schemas.QuizResponse])
async def get_user_quizzes(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    if current_user.id != user_id:
        raise HTTPException(status_code=403, detail="권한이 없습니다")
    
    quizzes = db.query(models.Quiz).filter(
        models.Quiz.user_id == user_id
    ).order_by(models.Quiz.created_at.desc()).all()
    return quizzes

@app.post("/api/quizzes", response_model=schemas.QuizResponse)
async def create_quiz(
    quiz_data: schemas.QuizCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    new_quiz = models.Quiz(
        quiz_name=quiz_data.quiz_name,
        user_id=current_user.id
    )
    db.add(new_quiz)
    db.flush()
    
    for q_data in quiz_data.questions:
        new_question = models.QuizQuestion(
            quiz_id=new_quiz.id,
            question_text=q_data.question_text,
            question_type=q_data.question_type,
            question_order=q_data.question_order,
            correct_answer=q_data.correct_answer
        )
        db.add(new_question)
        db.flush()
        
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
    return new_quiz

@app.delete("/api/quizzes/{quiz_id}")
async def delete_quiz(
    quiz_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    quiz = db.query(models.Quiz).filter(models.Quiz.id == quiz_id).first()
    if not quiz:
        raise HTTPException(status_code=404, detail="퀴즈를 찾을 수 없습니다")
    if quiz.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="권한이 없습니다")
    
    db.delete(quiz)
    db.commit()
    return {"message": "퀴즈가 삭제되었습니다"}

# [추가됨] 퀴즈 질문 수정 API
@app.put("/api/questions/{question_id}", response_model=schemas.QuizQuestionResponse)
def update_question(
    question_id: int,
    question_update: schemas.QuizQuestionUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    # 1. 질문 조회
    db_question = db.query(models.QuizQuestion).filter(models.QuizQuestion.id == question_id).first()
    if not db_question:
        raise HTTPException(status_code=404, detail="질문을 찾을 수 없습니다.")
    
    # 2. 권한 확인
    if db_question.quiz.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="수정 권한이 없습니다.")
    
    # 3. 질문 텍스트 및 서술형 정답 수정
    if question_update.question_text:
        db_question.question_text = question_update.question_text
    if question_update.correct_answer:
        db_question.correct_answer = question_update.correct_answer

    # 4. 객관식 보기(Answers) 수정 로직
    if question_update.answers is not None:
        # 기존 보기 삭제
        db.query(models.QuizAnswer).filter(models.QuizAnswer.question_id == question_id).delete()
        
        # 새 보기 추가
        for a in question_update.answers:
            new_answer = models.QuizAnswer(
                question_id=question_id,
                answer_text=a.answer_text,
                is_correct=a.is_correct,
                answer_order=a.answer_order
            )
            db.add(new_answer)

    db.commit()
    db.refresh(db_question)
    return db_question

# ===== 진행 상황 엔드포인트 =====

@app.post("/api/progress")
async def submit_progress(
    progress_data: schemas.ProgressSubmit,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    for result in progress_data.results:
        question_id = result["question_id"]
        is_correct = result["is_correct"]
        
        progress = db.query(models.UserProgress).filter(
            models.UserProgress.user_id == current_user.id,
            models.UserProgress.question_id == question_id
        ).first()
        
        if not progress:
            progress = models.UserProgress(
                user_id=current_user.id,
                question_id=question_id,
                is_correct=is_correct,
                attempt_count=1,
                correct_count=1 if is_correct else 0,
                interval_days=1,
                next_review_date=datetime.utcnow() + timedelta(days=1),
                last_reviewed_at=datetime.utcnow()
            )
            db.add(progress)
        else:
            progress.attempt_count += 1
            progress.last_reviewed_at = datetime.utcnow()
            progress.is_correct = is_correct
            
            if is_correct:
                progress.correct_count += 1
                progress.interval_days = min(progress.interval_days * 2, 30)
            else:
                progress.interval_days = 1
            
            progress.next_review_date = datetime.utcnow() + timedelta(days=progress.interval_days)
    
    db.commit()
    return {"message": "진행 상황이 저장되었습니다"}

@app.get("/api/users/{user_id}/progress", response_model=List[schemas.ProgressResponse])
async def get_user_progress(
    user_id: int,
    review_due: bool = False,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(auth.get_current_user)
):
    if current_user.id != user_id:
        raise HTTPException(status_code=403, detail="권한이 없습니다")
    
    query = db.query(models.UserProgress).filter(
        models.UserProgress.user_id == user_id
    )
    
    if review_due:
        query = query.filter(
            models.UserProgress.next_review_date <= datetime.utcnow()
        )
    
    progress_list = query.all()
    return progress_list

# ===== PDF AI 퀴즈 생성 엔드포인트 =====

@app.post("/api/quizzes/generate-from-pdf")
async def generate_quiz_from_pdf(
    file: UploadFile = File(...),
    num_questions: int = Form(5),
    question_types: str = Form("mixed"),
    current_user: Optional[models.User] = Depends(auth.get_current_user_optional)
):
    try:
        if not file.filename.endswith('.pdf'):
            raise HTTPException(status_code=400, detail="PDF 파일만 업로드 가능합니다")
        
        contents = await file.read()
        from io import BytesIO
        pdf_file = BytesIO(contents)
        pdf_file.name = file.filename
        
        text = extract_text_from_pdf(pdf_file)
        if not text:
            raise HTTPException(status_code=400, detail="PDF에서 텍스트를 추출할 수 없습니다")
        
        text = truncate_text(text, max_tokens=5000)
        
        questions = generate_quiz_from_text(
            text=text,
            num_questions=num_questions,
            question_types=question_types
        )
        
        if not questions:
            raise HTTPException(status_code=500, detail="AI 퀴즈 생성에 실패했습니다")
        
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

if __name__ == "__main__":
    import uvicorn
    import socket
    
    hostname = socket.gethostname()
    local_ip = socket.gethostbyname(hostname)
    
    print(f"Server IP: {local_ip}:8000")
    print("=" * 50)
    print("🚀 Feynman Learning & Quiz 서버 시작")
    print(f"📍 Local IP: http://{local_ip}:8000")
    print(f"📍 Localhost: http://localhost:8000")
    print("=" * 50)
    
    uvicorn.run(app, host="0.0.0.0", port=8000)