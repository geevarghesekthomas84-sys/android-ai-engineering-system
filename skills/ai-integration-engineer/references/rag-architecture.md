# RAG (Retrieval-Augmented Generation) Architecture

## Overview

RAG enhances LLM responses by retrieving relevant context from your own data
before generating an answer. This prevents hallucination and keeps responses
grounded in your actual content.

## Architecture

```
User Query → Embedding → Vector Search → Top-K Chunks → LLM Prompt → Response
                                              ↑
                            Document Ingestion Pipeline
                            (Extract → Chunk → Embed → Store)
```

## Document Ingestion Pipeline

### 1. Text Extraction

```python
# FastAPI ingestion endpoint
from fastapi import UploadFile
import fitz  # PyMuPDF

@app.post("/ingest")
async def ingest_document(file: UploadFile):
    if file.filename.endswith(".pdf"):
        pdf = fitz.open(stream=await file.read(), filetype="pdf")
        text = "\n".join(page.get_text() for page in pdf)
    elif file.filename.endswith(".txt"):
        text = (await file.read()).decode("utf-8")
    else:
        raise HTTPException(400, "Unsupported format")

    chunks = chunk_text(text)
    embeddings = await generate_embeddings(chunks)
    await store_vectors(file.filename, chunks, embeddings)
    return {"chunks": len(chunks)}
```

### 2. Chunking Strategies

```python
def chunk_fixed_size(text: str, size: int = 512, overlap: int = 64) -> list[str]:
    words = text.split()
    chunks = []
    for i in range(0, len(words), size - overlap):
        chunks.append(" ".join(words[i:i + size]))
    return chunks

def chunk_by_paragraph(text: str, max_tokens: int = 512) -> list[str]:
    paragraphs = text.split("\n\n")
    chunks, current = [], ""
    for p in paragraphs:
        if len((current + p).split()) > max_tokens:
            if current:
                chunks.append(current.strip())
            current = p
        else:
            current += "\n\n" + p
    if current:
        chunks.append(current.strip())
    return chunks
```

**Chunking guidelines:**
- 256–512 tokens per chunk for most use cases
- 10–20% overlap to preserve context across boundaries
- Preserve paragraph/section boundaries when possible
- Include metadata (source file, page number, section title)

### 3. Embedding Generation

```python
import httpx

async def generate_embeddings(chunks: list[str]) -> list[list[float]]:
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.openai.com/v1/embeddings",
            headers={"Authorization": f"Bearer {settings.openai_key}"},
            json={
                "model": "text-embedding-3-small",
                "input": chunks,
            },
        )
        data = response.json()
        return [item["embedding"] for item in data["data"]]
```

**Model options:**
| Model | Dimensions | Cost | Quality |
|-------|-----------|------|---------|
| text-embedding-3-small | 1536 | Low | Good |
| text-embedding-3-large | 3072 | Medium | Better |
| sentence-transformers (local) | 384–768 | Free | Good |

### 4. Vector Storage

**pgvector (PostgreSQL extension):**
```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE document_chunks (
    id SERIAL PRIMARY KEY,
    source TEXT NOT NULL,
    content TEXT NOT NULL,
    embedding vector(1536),
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX ON document_chunks
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);
```

```python
async def store_vectors(source: str, chunks: list[str], embeddings: list[list[float]]):
    async with db.transaction():
        for chunk, emb in zip(chunks, embeddings):
            await db.execute(
                "INSERT INTO document_chunks (source, content, embedding) VALUES ($1, $2, $3)",
                source, chunk, emb,
            )
```

**Other vector databases:** Pinecone (managed), Chroma (embedded), Weaviate, Qdrant, Milvus.

## Retrieval

### Similarity Search

```python
async def search_similar(query: str, top_k: int = 5) -> list[dict]:
    query_embedding = (await generate_embeddings([query]))[0]
    rows = await db.fetch(
        """
        SELECT content, source, 1 - (embedding <=> $1::vector) AS similarity
        FROM document_chunks
        ORDER BY embedding <=> $1::vector
        LIMIT $2
        """,
        query_embedding, top_k,
    )
    return [{"content": r["content"], "source": r["source"], "score": r["similarity"]} for r in rows]
```

### Hybrid Search (Semantic + Keyword)

```sql
-- Combine vector similarity with full-text search
SELECT content,
    (0.7 * (1 - (embedding <=> $1::vector))) +
    (0.3 * ts_rank(to_tsvector('english', content), plainto_tsquery('english', $2))) AS score
FROM document_chunks
ORDER BY score DESC
LIMIT 5;
```

## Prompt Construction

```python
async def rag_query(user_question: str) -> str:
    chunks = await search_similar(user_question, top_k=5)

    context = "\n\n---\n\n".join(
        f"[Source: {c['source']}]\n{c['content']}" for c in chunks
    )

    messages = [
        {
            "role": "system",
            "content": (
                "Answer the user's question based on the provided context. "
                "If the context doesn't contain enough information, say so. "
                "Cite sources when possible."
            ),
        },
        {
            "role": "user",
            "content": f"Context:\n{context}\n\nQuestion: {user_question}",
        },
    ]

    response = await anthropic_client.messages.create(
        model="claude-sonnet-4-20250514",
        max_tokens=1024,
        messages=messages,
    )
    return response.content[0].text
```

## Re-Ranking

After retrieval, re-rank results to improve relevance:

```python
async def rerank(query: str, chunks: list[dict], top_n: int = 3) -> list[dict]:
    # Use a cross-encoder model for more accurate relevance scoring
    scored = []
    for chunk in chunks:
        score = await cross_encoder.predict(query, chunk["content"])
        scored.append({**chunk, "rerank_score": score})
    scored.sort(key=lambda x: x["rerank_score"], reverse=True)
    return scored[:top_n]
```

## Android Client Integration

```kotlin
// Repository calling RAG endpoint
class RagRepository(private val api: RagApi) {
    fun askQuestion(question: String): Flow<String> = flow {
        val response = api.query(QueryRequest(question))
        emit(response.answer)
    }
}

// API interface
interface RagApi {
    @POST("rag/query")
    suspend fun query(@Body request: QueryRequest): QueryResponse
}

@Serializable
data class QueryRequest(val question: String)

@Serializable
data class QueryResponse(val answer: String, val sources: List<String>)
```

## Best Practices

1. **Chunk size matters** — too small loses context, too large dilutes relevance
2. **Include metadata** — source, page, section for citation
3. **Use hybrid search** — semantic + keyword catches more relevant content
4. **Re-rank** — cross-encoder re-ranking significantly improves quality
5. **Monitor retrieval quality** — log queries, retrieved chunks, and user feedback
6. **Cache embeddings** — don't re-embed unchanged documents
7. **Handle token limits** — total context (system + retrieved + query) must fit model's window
