#!/usr/bin/env python3
"""
Quiz 시스템 테이블 추가 Migration
- quizzes: 퀴즈 컨테이너
- quiz_questions: 퀴즈 문제
- quiz_answers: 선택지 (4지선다용)
- user_progress: 학습 진척도 (Spaced Repetition)
"""

from sqlalchemy import create_engine
from database import DATABASE_URL
from models import Base, Quiz, QuizQuestion, QuizAnswer, UserProgress

def migrate():
    """Quiz 관련 테이블 생성"""
    print("=" * 50)
    print("🔧 Quiz 시스템 테이블 생성 시작")
    print(f"📍 Database: {DATABASE_URL}")
    print("=" * 50)

    engine = create_engine(DATABASE_URL)

    # Quiz 관련 테이블만 생성 (checkfirst=True로 중복 방지)
    tables = [
        ('quizzes', Quiz.__table__),
        ('quiz_questions', QuizQuestion.__table__),
        ('quiz_answers', QuizAnswer.__table__),
        ('user_progress', UserProgress.__table__),
    ]

    for table_name, table in tables:
        try:
            table.create(engine, checkfirst=True)
            print(f"✅ {table_name} 테이블 생성 완료")
        except Exception as e:
            print(f"❌ {table_name} 테이블 생성 실패: {e}")

    print("=" * 50)
    print("🎉 Migration 완료!")
    print("=" * 50)

if __name__ == "__main__":
    migrate()
