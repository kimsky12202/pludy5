#!/usr/bin/env python3
"""
데이터베이스 마이그레이션: chat_rooms 테이블에 original_question 컬럼 추가
"""
from sqlalchemy import create_engine, text
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

def migrate():
    engine = create_engine(DATABASE_URL)

    with engine.connect() as conn:
        # 컬럼이 이미 존재하는지 확인
        check_query = text("""
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name='chat_rooms' AND column_name='original_question'
        """)

        result = conn.execute(check_query).fetchone()

        if result:
            print("✅ original_question 컬럼이 이미 존재합니다.")
            return

        # 컬럼 추가
        alter_query = text("""
            ALTER TABLE chat_rooms
            ADD COLUMN original_question TEXT
        """)

        conn.execute(alter_query)
        conn.commit()

        print("✅ original_question 컬럼이 성공적으로 추가되었습니다.")

        # 확인
        verify_query = text("""
            SELECT column_name, data_type
            FROM information_schema.columns
            WHERE table_name='chat_rooms'
            ORDER BY ordinal_position
        """)

        columns = conn.execute(verify_query).fetchall()
        print("\n📋 chat_rooms 테이블 컬럼 목록:")
        for col in columns:
            print(f"  - {col[0]}: {col[1]}")

if __name__ == "__main__":
    try:
        migrate()
    except Exception as e:
        print(f"❌ 마이그레이션 실패: {e}")
        raise
