"""
퀴즈 질문에 이미지 필드 추가 마이그레이션
"""
from sqlalchemy import create_engine, text
from database import DATABASE_URL

def migrate():
    engine = create_engine(DATABASE_URL)

    with engine.connect() as conn:
        # image_data 컬럼 추가
        try:
            conn.execute(text("""
                ALTER TABLE quiz_questions
                ADD COLUMN image_data TEXT;
            """))
            conn.commit()
            print("✅ quiz_questions 테이블에 image_data 컬럼 추가 완료")
        except Exception as e:
            print(f"⚠️  마이그레이션 중 오류 (이미 존재할 수 있음): {e}")

if __name__ == "__main__":
    migrate()
