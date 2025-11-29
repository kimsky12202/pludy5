"""
Schedule 테이블의 color 컬럼을 Integer에서 BigInteger로 변경하는 마이그레이션
Flutter Color.value는 unsigned 32-bit (0 ~ 4294967295)이므로 BigInteger 필요
"""
from sqlalchemy import create_engine, text
from database import DATABASE_URL

def migrate():
    engine = create_engine(DATABASE_URL)

    with engine.connect() as conn:
        print("📝 Schedule 테이블의 color 컬럼 타입 변경 중...")

        # color 컬럼을 BIGINT로 변경
        conn.execute(text("""
            ALTER TABLE schedules
            ALTER COLUMN color TYPE BIGINT
        """))

        conn.commit()
        print("✅ color 컬럼 타입 변경 완료: INTEGER → BIGINT")

if __name__ == "__main__":
    try:
        migrate()
        print("\n✨ 마이그레이션 성공!")
    except Exception as e:
        print(f"\n❌ 마이그레이션 실패: {e}")
        raise
