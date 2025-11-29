# backend/reset_db.py (수정 버전)
from sqlalchemy import create_engine
from database import Base, DATABASE_URL

# 모든 모델 import (중요!)
from models import (
    ChatRoom, 
    Message, 
    User, 
    Quiz, 
    QuizQuestion, 
    QuizAnswer, 
    UserProgress
)

# 엔진 생성
engine = create_engine(DATABASE_URL)

# 기존 테이블 삭제
Base.metadata.drop_all(bind=engine)
print("기존 테이블 삭제됨")

# 새 테이블 생성
Base.metadata.create_all(bind=engine)
print("새 테이블 생성됨")

print("\n테이블 구조 확인:")
from sqlalchemy import inspect
inspector = inspect(engine)

for table in inspector.get_table_names():
    columns = inspector.get_columns(table)
    print(f"\n{table}:")
    for col in columns:
        print(f"  - {col['name']}: {col['type']}")

print("\n✅ 데이터베이스 초기화 완료!")
print(f"생성된 테이블 수: {len(inspector.get_table_names())}")