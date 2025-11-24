# backend/rag_system.py
import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer
import PyPDF2
from typing import List, Dict
import os

# backend/rag_system.py
import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer
import PyPDF2
from typing import List, Dict, Optional
import os

class RAGSystem:
    """ChromaDB 기반 RAG 시스템 (User 기반, PDF별 구분)"""
    
    def __init__(self):
        # ChromaDB 클라이언트 초기화
        self.client = chromadb.Client(Settings(
            persist_directory="./chroma_db",
            anonymized_telemetry=False
        ))
        
        # 임베딩 모델 초기화
        self.embedding_model = SentenceTransformer('all-MiniLM-L6-v2')
        
        print("✅ RAG 시스템 초기화 완료")
    
    def get_or_create_collection(self, user_id: str):
        """사용자별 컬렉션 (모든 PDF를 하나의 collection에 저장)"""
        collection_name = f"user_{user_id}"
        try:
            collection = self.client.get_collection(collection_name)
        except:
            collection = self.client.create_collection(collection_name)
        return collection
    
    def extract_text_from_pdf(self, pdf_path: str) -> List[Dict[str, str]]:
        """PDF에서 텍스트 추출 (페이지별)"""
        chunks = []
        
        with open(pdf_path, 'rb') as file:
            pdf_reader = PyPDF2.PdfReader(file)
            
            for page_num, page in enumerate(pdf_reader.pages):
                text = page.extract_text()
                
                if text.strip():
                    chunks.append({
                        'text': text,
                        'page': page_num + 1,
                        'metadata': f'Page {page_num + 1}'
                    })
        
        print(f"📄 PDF에서 {len(chunks)}개 페이지 추출 완료")
        return chunks
    
    def add_pdf_to_collection(
        self, 
        user_id: str, 
        pdf_id: str, 
        pdf_path: str, 
        filename: str
    ) -> bool:
        """PDF 내용을 ChromaDB에 저장 (PDF별로 구분)"""
        try:
            collection = self.get_or_create_collection(user_id)
            
            # PDF 텍스트 추출
            chunks = self.extract_text_from_pdf(pdf_path)
            
            if not chunks:
                print("❌ PDF에서 텍스트를 추출할 수 없습니다")
                return False
            
            # ChromaDB에 저장 (PDF ID 포함)
            for chunk in chunks:
                doc_id = f"{user_id}_pdf_{pdf_id}_page_{chunk['page']}"
                
                # 중복 체크 (이미 업로드된 경우 스킵)
                try:
                    collection.get(ids=[doc_id])
                    continue  # 이미 존재함
                except:
                    pass
                
                collection.add(
                    documents=[chunk['text']],
                    metadatas=[{
                        'page': chunk['page'],
                        'pdf_id': pdf_id,
                        'filename': filename,
                        'user_id': user_id
                    }],
                    ids=[doc_id]
                )
            
            print(f"✅ {len(chunks)}개 청크 저장 완료 (User: {user_id}, PDF: {filename})")
            return True
            
        except Exception as e:
            print(f"❌ PDF 저장 오류: {e}")
            return False
    
    def search_by_pdf(
        self,
        user_id: str,
        pdf_id: str,
        query: str,
        n_results: int = 3
    ) -> List[Dict]:
        """특정 PDF에서만 검색 (채팅방용)"""
        try:
            collection = self.get_or_create_collection(user_id)
            
            if collection.count() == 0:
                return []
            
            # pdf_id로 필터링해서 검색
            results = collection.query(
                query_texts=[query],
                n_results=n_results,
                where={"pdf_id": pdf_id}  # 🔑 핵심: 특정 PDF만 검색
            )
            
            contexts = []
            if results['documents'] and results['documents'][0]:
                for i, doc in enumerate(results['documents'][0]):
                    metadata = results['metadatas'][0][i] if results['metadatas'] else {}
                    contexts.append({
                        'content': doc,
                        'page': metadata.get('page', 'Unknown'),
                        'filename': metadata.get('filename', 'Unknown')
                    })
            
            print(f"🔍 {len(contexts)}개 관련 내용 검색됨 (PDF: {pdf_id})")
            return contexts
            
        except Exception as e:
            print(f"❌ 검색 오류: {e}")
            return []
    
    def search_all_pdfs(
        self,
        user_id: str,
        query: str,
        n_results: int = 5
    ) -> List[Dict]:
        """사용자의 모든 PDF에서 검색 (파일뷰어용)"""
        try:
            collection = self.get_or_create_collection(user_id)
            
            if collection.count() == 0:
                return []
            
            # 필터링 없이 전체 검색
            results = collection.query(
                query_texts=[query],
                n_results=n_results
            )
            
            contexts = []
            if results['documents'] and results['documents'][0]:
                for i, doc in enumerate(results['documents'][0]):
                    metadata = results['metadatas'][0][i] if results['metadatas'] else {}
                    contexts.append({
                        'content': doc,
                        'page': metadata.get('page', 'Unknown'),
                        'pdf_id': metadata.get('pdf_id', 'Unknown'),
                        'filename': metadata.get('filename', 'Unknown')
                    })
            
            print(f"🔍 {len(contexts)}개 관련 내용 검색됨 (전체 PDF)")
            return contexts
            
        except Exception as e:
            print(f"❌ 검색 오류: {e}")
            return []
    
    def delete_pdf_from_collection(self, user_id: str, pdf_id: str) -> bool:
        """특정 PDF의 모든 청크 삭제"""
        try:
            collection = self.get_or_create_collection(user_id)
            collection.delete(where={"pdf_id": pdf_id})
            
            print(f"✅ PDF 청크 삭제 완료 (PDF: {pdf_id})")
            return True
            
        except Exception as e:
            print(f"❌ PDF 삭제 오류: {e}")
            return False
    
    def has_pdf(self, user_id: str, pdf_id: str) -> bool:
        """특정 PDF가 RAG에 등록되어 있는지 확인"""
        try:
            collection = self.get_or_create_collection(user_id)
            results = collection.get(where={"pdf_id": pdf_id}, limit=1)
            return len(results['ids']) > 0
        except:
            return False

# 전역 인스턴스
rag_system = RAGSystem()