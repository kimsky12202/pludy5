#!/usr/bin/env python3
"""
데이터베이스 마이그레이션: Planner 테이블 추가 (goals, schedules, subjects)
"""
from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

def migrate():
    engine = create_engine(DATABASE_URL)

    with engine.connect() as conn:
        print("🔧 Planner 테이블 생성 시작...")

        # Goals 테이블 생성
        try:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS goals (
                    id VARCHAR PRIMARY KEY,
                    user_id VARCHAR NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    title VARCHAR(200) NOT NULL,
                    description TEXT,
                    deadline TIMESTAMP NOT NULL,
                    is_completed BOOLEAN DEFAULT FALSE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            conn.commit()
            print("✅ goals 테이블 생성 완료")
        except Exception as e:
            print(f"⚠️ goals 테이블 생성 오류 (이미 존재할 수 있음): {e}")

        # Schedules 테이블 생성
        try:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS schedules (
                    id VARCHAR PRIMARY KEY,
                    user_id VARCHAR NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    date TIMESTAMP NOT NULL,
                    title VARCHAR(200) NOT NULL,
                    description TEXT,
                    start_time VARCHAR(5),
                    end_time VARCHAR(5),
                    is_completed BOOLEAN DEFAULT FALSE,
                    color INTEGER
                )
            """))
            conn.commit()
            print("✅ schedules 테이블 생성 완료")
        except Exception as e:
            print(f"⚠️ schedules 테이블 생성 오류 (이미 존재할 수 있음): {e}")

        # Subjects 테이블 생성
        try:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS subjects (
                    id VARCHAR PRIMARY KEY,
                    user_id VARCHAR NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    name VARCHAR(100) NOT NULL,
                    credits REAL NOT NULL,
                    grade VARCHAR(2) NOT NULL,
                    year INTEGER NOT NULL,
                    semester INTEGER NOT NULL
                )
            """))
            conn.commit()
            print("✅ subjects 테이블 생성 완료")
        except Exception as e:
            print(f"⚠️ subjects 테이블 생성 오류 (이미 존재할 수 있음): {e}")

        # 인덱스 생성 (성능 향상)
        try:
            conn.execute(text("CREATE INDEX IF NOT EXISTS idx_goals_user_id ON goals(user_id)"))
            conn.execute(text("CREATE INDEX IF NOT EXISTS idx_goals_deadline ON goals(deadline)"))
            conn.execute(text("CREATE INDEX IF NOT EXISTS idx_schedules_user_id ON schedules(user_id)"))
            conn.execute(text("CREATE INDEX IF NOT EXISTS idx_schedules_date ON schedules(date)"))
            conn.execute(text("CREATE INDEX IF NOT EXISTS idx_subjects_user_id ON subjects(user_id)"))
            conn.commit()
            print("✅ 인덱스 생성 완료")
        except Exception as e:
            print(f"⚠️ 인덱스 생성 오류 (이미 존재할 수 있음): {e}")

        # 테이블 확인
        result = conn.execute(text("""
            SELECT tablename FROM pg_tables
            WHERE schemaname = 'public'
            AND tablename IN ('goals', 'schedules', 'subjects')
            ORDER BY tablename
        """))
        tables = result.fetchall()

        print("\n📋 생성된 Planner 테이블:")
        for table in tables:
            print(f"  - {table[0]}")

if __name__ == "__main__":
    try:
        migrate()
        print("\n🎉 마이그레이션 완료!")
    except Exception as e:
        print(f"\n❌ 마이그레이션 실패: {e}")
        raise
