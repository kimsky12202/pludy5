# backend/quiz_generator.py
import requests
import json
import random
import time
from typing import List, Dict, Optional

OLLAMA_BASE_URL = "http://localhost:11434"

# ============================================================
# [추가됨] 재시도를 위해 필요한 최소한의 도구들 (원본 로직 보호용)
# ============================================================
def extract_json_object(text: str) -> Optional[str]:
    try:
        start_idx = text.find('{')
        if start_idx == -1: return None
        end_idx = text.rfind('}')
        if end_idx == -1 or end_idx < start_idx: return None
        return text[start_idx : end_idx + 1]
    except Exception:
        return None

def repair_json(json_str: str) -> Optional[Dict]:
    try:
        return json.loads(json_str)
    except json.JSONDecodeError:
        try:
            # 마지막 쉼표 제거 후 닫기
            last_valid_comma = json_str.rfind('},')
            if last_valid_comma != -1:
                repaired = json_str[:last_valid_comma+1] + ' ]}'
                return json.loads(repaired)
            # 강제로 괄호 닫기
            trimmed = json_str.strip()
            if trimmed.endswith(','): trimmed = trimmed[:-1]
            if not trimmed.endswith(']'): trimmed += ']'
            if not trimmed.endswith('}'): trimmed += '}'
            return json.loads(trimmed)
        except:
            return None

# ============================================================
# [메인 함수] 사용자님 원본 코드 로직 유지 + 재시도 루프 적용
# ============================================================
def generate_quiz_from_text(
    text: str, 
    num_questions: int = 5,
    question_types: str = "mixed"
) -> Optional[List[Dict]]:
    """
    텍스트를 기반으로 AI가 퀴즈 문제 생성 (최대 20개)
    """
    
    # 실제로는 더 많이 요청 (최대 25개)
    request_num = min(num_questions + 5, 25)
    
    # [추가됨] 실패 시 반환할 데이터 저장소
    best_attempt_questions = []
    MAX_RETRIES = 5  # 5번 재시도 설정

    # =========================================================
    # [1] 프롬프트 생성 (사용자님 원본 그대로 사용 - 절대 줄이지 않음)
    # =========================================================
    if question_types == "multiple_choice":
        # 4지선다만
        prompt = f"""다음 텍스트를 읽고 정확히 {request_num}개의 4지선다 퀴즈를 만드세요.

텍스트:
{text}

**필수 규칙:**
1. 정확히 {request_num}개의 문제
2. 모든 문제는 4지선다
3. 각 문제는 정확히 4개의 선택지
4. 정답은 1개만
5. 하나의 JSON 객체

JSON 형식:
{{
  "questions": [
    {{
      "question_text": "HTML은 무엇을 의미하나요?",
      "question_type": "multiple_choice",
      "answers": [
        {{"answer_text": "HyperText Markup Language", "is_correct": true, "answer_order": 0}},
        {{"answer_text": "High Tech Modern Language", "is_correct": false, "answer_order": 1}},
        {{"answer_text": "Home Tool Markup Language", "is_correct": false, "answer_order": 2}},
        {{"answer_text": "Hyperlinks Text Markup", "is_correct": false, "answer_order": 3}}
      ]
    }},
    {{
      "question_text": "두 번째 질문",
      "question_type": "multiple_choice",
      "answers": [
        {{"answer_text": "답 1", "is_correct": false, "answer_order": 0}},
        {{"answer_text": "답 2", "is_correct": true, "answer_order": 1}},
        {{"answer_text": "답 3", "is_correct": false, "answer_order": 2}},
        {{"answer_text": "답 4", "is_correct": false, "answer_order": 3}}
      ]
    }}
  ]
}}

지금 {request_num}개의 4지선다 문제를 JSON으로만 출력하세요:
"""
    
    elif question_types == "short_answer":
        # 서술형만
        prompt = f"""다음 텍스트를 읽고 정확히 {request_num}개의 서술형 퀴즈를 만드세요.

텍스트:
{text}

**필수 규칙:**
1. 정확히 {request_num}개의 문제
2. 모든 문제는 서술형 (4지선다 절대 금지!)
3. correct_answer 필드 필수
4. 하나의 JSON 객체

JSON 형식:
{{
  "questions": [
    {{
      "question_text": "HTML의 정식 명칭을 쓰시오.",
      "question_type": "short_answer",
      "correct_answer": "HyperText Markup Language"
    }},
    {{
      "question_text": "웹 페이지의 구조를 정의하는 언어는?",
      "question_type": "short_answer",
      "correct_answer": "HTML"
    }},
    {{
      "question_text": "HTML 태그의 기본 구조를 설명하시오.",
      "question_type": "short_answer",
      "correct_answer": "여는 태그와 닫는 태그로 구성되며 내용을 감싼다"
    }}
  ]
}}

지금 {request_num}개의 서술형 문제를 JSON으로만 출력하세요:
"""
    
    else:  # mixed
        # 혼합
        prompt = f"""다음 텍스트를 읽고 정확히 {request_num}개의 퀴즈를 만드세요. 4지선다와 서술형을 섞으세요.

텍스트:
{text}

**필수 규칙:**
1. 정확히 {request_num}개의 문제
2. 4지선다와 서술형을 섞음 (약 반반)
3. 4지선다는 정확히 4개의 선택지
4. 서술형은 correct_answer 필드
5. 하나의 JSON 객체
6. 생략 표시 절대 금지

완전한 JSON 형식:
{{
  "questions": [
    {{
      "question_text": "HTML은 무엇인가요?",
      "question_type": "multiple_choice",
      "answers": [
        {{"answer_text": "마크업 언어", "is_correct": true, "answer_order": 0}},
        {{"answer_text": "프로그래밍 언어", "is_correct": false, "answer_order": 1}},
        {{"answer_text": "스타일 언어", "is_correct": false, "answer_order": 2}},
        {{"answer_text": "데이터베이스", "is_correct": false, "answer_order": 3}}
      ]
    }},
    {{
      "question_text": "HTML의 정식 명칭을 쓰시오.",
      "question_type": "short_answer",
      "correct_answer": "HyperText Markup Language"
    }},
    {{
      "question_text": "웹 브라우저의 역할은?",
      "question_type": "multiple_choice",
      "answers": [
        {{"answer_text": "HTML 해석 및 렌더링", "is_correct": true, "answer_order": 0}},
        {{"answer_text": "코드 작성", "is_correct": false, "answer_order": 1}},
        {{"answer_text": "서버 관리", "is_correct": false, "answer_order": 2}},
        {{"answer_text": "데이터 저장", "is_correct": false, "answer_order": 3}}
      ]
    }},
    {{
      "question_text": "태그의 기본 구조를 설명하시오.",
      "question_type": "short_answer",
      "correct_answer": "여는 태그와 닫는 태그로 구성"
    }}
  ]
}}

위처럼 모든 문제를 완전히 작성하여 {request_num}개를 JSON으로만 출력하세요.
"..." 같은 생략 절대 금지:
"""

    # =========================================================
    # [2] 재시도 루프 시작 (User Code Wrap)
    # =========================================================
    for attempt in range(MAX_RETRIES):
        try:
            print(f"🤖 AI에게 {request_num}개 문제 생성 요청 중... (시도 {attempt + 1}/{MAX_RETRIES})")
            print(f"📋 문제 유형: {question_types}")
            
            # Ollama API 호출 (타임아웃만 조금 늘림)
            response = requests.post(
                f"{OLLAMA_BASE_URL}/api/generate",
                json={
                    "model": "llama3.1:8b",
                    "prompt": prompt,
                    "stream": False,
                    "temperature": 0.7,
                    "num_predict": 8192,  # 4096 → 8192로 증가!
                },
                timeout=600  # 타임아웃 10분
            )
            
            if response.status_code != 200:
                print(f"❌ Ollama API 오류: {response.status_code}")
                time.sleep(2) # [추가] 재시도 대기
                continue # [추가] 다음 시도로 넘어감
            
            # 응답 파싱
            result = response.json()
            generated_text = result.get("response", "")
            
            print(f"📝 AI 응답 길이: {len(generated_text)} 글자")
            
            # JSON 추출 및 정제 (제가 드린 도구 사용)
            generated_text = generated_text.replace('```json', '').replace('```', '').strip()
            json_text = extract_json_object(generated_text) or generated_text
            
            # 파싱 및 복구 (제가 드린 도구 사용)
            quiz_data = repair_json(json_text)
            
            if not quiz_data:
                print("❌ JSON 파싱 오류. 재시도합니다.")
                continue # [추가] 실패 시 재시도

            questions = quiz_data.get("questions", [])
            print(f"🔍 파싱된 문제 수: {len(questions)}개")
            
            if not questions:
                print("❌ 문제가 없습니다. 재시도합니다.")
                continue # [추가] 실패 시 재시도
            
            # =========================================================
            # [3] 유효성 검증 (사용자님 원본 코드 100% 유지)
            # =========================================================
            validated_questions = []
            for idx, q in enumerate(questions):
                if not q.get("question_text"):
                    # print(f"⚠️ 문제 {idx+1}: 질문 없음")
                    continue
                
                q_type = q.get("question_type", "")
                
                # 서술형 먼저 체크
                if q_type == "short_answer" or ("correct_answer" in q and "answers" not in q):
                    if not q.get("correct_answer"):
                        # print(f"⚠️ 문제 {idx+1}: 서술형인데 정답 없음")
                        continue
                    
                    q["question_type"] = "short_answer"
                    validated_questions.append(q)
                    # print(f"✅ 문제 {idx+1}: 서술형")
                
                # 4지선다
                elif q_type == "multiple_choice" or "answers" in q:
                    answers = q.get("answers", [])
                    
                    if len(answers) < 2:
                        # print(f"⚠️ 문제 {idx+1}: 선택지 부족, 건너뜀")
                        continue
                    
                    # 4개로 맞추기
                    while len(answers) < 4:
                        answers.append({
                            "answer_text": f"선택지 {len(answers)+1}",
                            "is_correct": False,
                            "answer_order": len(answers)
                        })
                    
                    answers = answers[:4]
                    
                    # 정답 확인
                    correct_count = sum(1 for a in answers if a.get("is_correct"))
                    if correct_count == 0:
                        answers[0]["is_correct"] = True
                    elif correct_count > 1:
                        for i, a in enumerate(answers):
                            a["is_correct"] = (i == 0)
                    
                    # 🎲 랜덤 섞기
                    random.shuffle(answers)
                    for i, a in enumerate(answers):
                        a["answer_order"] = i
                    
                    q["question_type"] = "multiple_choice"
                    q["answers"] = answers
                    validated_questions.append(q)
                    
                    # correct_idx = [i+1 for i, a in enumerate(answers) if a.get('is_correct')][0]
                    # print(f"✅ 문제 {idx+1}: 4지선다 (정답 {correct_idx}번)")
                
                else:
                    # print(f"⚠️ 문제 {idx+1}: 유형 불명, 건너뜀")
                    continue
                
                if len(validated_questions) >= num_questions:
                    break
            
            print(f"✅ 검증 통과: {len(validated_questions)}개 문제")
            
            # [추가] 목표 달성 확인 및 최고 기록 저장
            if len(validated_questions) >= num_questions:
                print("🎉 목표 달성! 성공!")
                return validated_questions[:num_questions]
            else:
                print(f"⚠️ 목표({num_questions}개) 미달. 재시도합니다.")
                if len(validated_questions) > len(best_attempt_questions):
                    best_attempt_questions = validated_questions
            
        except requests.exceptions.Timeout:
            print("❌ Ollama 타임아웃 (6분). 재시도합니다.")
        except Exception as e:
            print(f"❌ 예외: {e}. 재시도합니다.")
            import traceback
            traceback.print_exc()
            time.sleep(1)

    # 5번 다 실패하면 그나마 제일 잘 나온 거라도 줌
    if best_attempt_questions:
        print(f"🏁 최대 재시도 도달. 확보된 {len(best_attempt_questions)}개만 반환합니다.")
        return best_attempt_questions

    return None