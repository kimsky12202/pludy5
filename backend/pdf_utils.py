# backend/pdf_utils.py
import PyPDF2
from typing import Optional, Union
from io import BytesIO

def extract_text_from_pdf(pdf_file: Union[BytesIO, any]) -> Optional[str]:
    """
    PDF 파일에서 텍스트 추출
    
    Args:
        pdf_file: BytesIO 객체 또는 UploadFile 객체
        
    Returns:
        추출된 텍스트 또는 None
    """
    try:
        # BytesIO 객체인 경우
        if isinstance(pdf_file, BytesIO):
            pdf_reader = PyPDF2.PdfReader(pdf_file)
        else:
            # UploadFile 객체인 경우
            pdf_reader = PyPDF2.PdfReader(pdf_file.file)
        
        # 모든 페이지의 텍스트 추출
        text_content = []
        for page_num in range(len(pdf_reader.pages)):
            page = pdf_reader.pages[page_num]
            text = page.extract_text()
            if text:
                text_content.append(text)
        
        # 텍스트 결합
        full_text = "\n".join(text_content)
        
        # 빈 텍스트 체크
        if not full_text.strip():
            return None
            
        print(f"✅ PDF 추출 완료: {len(full_text)} 글자")
        return full_text
        
    except Exception as e:
        print(f"❌ PDF 텍스트 추출 오류: {e}")
        return None

def truncate_text(text: str, max_tokens: int = 3000) -> str:
    """
    텍스트를 최대 토큰 수로 제한
    대략 1 토큰 = 4자로 계산
    
    Args:
        text: 원본 텍스트
        max_tokens: 최대 토큰 수
        
    Returns:
        잘린 텍스트
    """
    max_chars = max_tokens * 4
    if len(text) <= max_chars:
        return text
    
    # 문장 단위로 자르기
    truncated = text[:max_chars]
    last_period = truncated.rfind('.')
    
    if last_period > 0:
        truncated_text = truncated[:last_period + 1]
        print(f"✂️ 텍스트 자름: {len(text)} → {len(truncated_text)} 글자")
        return truncated_text
    
    print(f"✂️ 텍스트 자름: {len(text)} → {max_chars} 글자")
    return truncated