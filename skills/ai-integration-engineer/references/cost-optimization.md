# AI Cost Optimization

## Token Counting and Estimation

```python
import tiktoken

def count_tokens(text: str, model: str = "gpt-4") -> int:
    encoding = tiktoken.encoding_for_model(model)
    return len(encoding.encode(text))

def estimate_cost(model: str, input_tokens: int, output_tokens: int) -> float:
    rates = {
        "claude-sonnet-4-20250514": (3.0 / 1_000_000, 15.0 / 1_000_000),
        "claude-haiku-3-5-20241022": (0.80 / 1_000_000, 4.0 / 1_000_000),
        "gpt-4o": (2.50 / 1_000_000, 10.0 / 1_000_000),
        "gpt-4o-mini": (0.15 / 1_000_000, 0.60 / 1_000_000),
    }
    input_rate, output_rate = rates.get(model, (0, 0))
    return input_tokens * input_rate + output_tokens * output_rate
```

## Model Selection by Task

| Task | Recommended Model | Why |
|------|------------------|-----|
| Classification/routing | Small model (Haiku, GPT-4o-mini) | Low cost, fast, sufficient accuracy |
| Summarization | Medium model (Sonnet, GPT-4o) | Good balance of quality and cost |
| Complex reasoning | Large model (Opus, o1) | Only when needed for accuracy |
| Embeddings | text-embedding-3-small | Cheapest, good quality |
| Code generation | Medium/Large model | Needs accuracy for correctness |

```python
class ModelRouter:
    async def select_model(self, task: str, complexity: str) -> str:
        if task in ("classify", "extract", "tag"):
            return "claude-haiku-3-5-20241022"
        if task == "summarize" or complexity == "low":
            return "claude-sonnet-4-20250514"
        return "claude-opus-4-20250514"
```

## Prompt Engineering for Efficiency

```python
# BAD: Verbose prompt (wastes tokens)
bad_prompt = """
I would like you to please analyze the following text and provide me with
a detailed summary of the key points. Please make sure to include all the
important information and organize it in a clear and concise manner...
"""

# GOOD: Concise prompt (saves tokens)
good_prompt = "Summarize the key points:\n\n{text}"
```

**Tips:**
- Remove filler words from system prompts
- Use structured output (JSON) to reduce output tokens
- Set appropriate `max_tokens` limits
- Use `stop` sequences to prevent over-generation

## Response Caching

### Semantic Cache

```python
from functools import lru_cache
import hashlib

class SemanticCache:
    def __init__(self, similarity_threshold: float = 0.95):
        self.threshold = similarity_threshold
        self.cache: dict[str, tuple[list[float], str]] = {}

    async def get(self, query: str) -> str | None:
        query_embedding = await embed(query)
        for key, (cached_embedding, response) in self.cache.items():
            similarity = cosine_similarity(query_embedding, cached_embedding)
            if similarity >= self.threshold:
                return response
        return None

    async def set(self, query: str, response: str):
        embedding = await embed(query)
        self.cache[query] = (embedding, response)
```

### Exact Cache with TTL

```python
import redis
import json
import hashlib

cache = redis.Redis()

async def cached_llm_call(prompt: str, ttl: int = 3600) -> str:
    cache_key = f"llm:{hashlib.sha256(prompt.encode()).hexdigest()}"

    cached = cache.get(cache_key)
    if cached:
        return json.loads(cached)["response"]

    response = await llm_client.create(messages=[{"role": "user", "content": prompt}])
    cache.setex(cache_key, ttl, json.dumps({"response": response.text}))
    return response.text
```

## Request Batching

```python
import asyncio

class BatchProcessor:
    def __init__(self, batch_size: int = 10, max_wait: float = 0.5):
        self.batch_size = batch_size
        self.max_wait = max_wait
        self.queue: list[tuple[str, asyncio.Future]] = []

    async def process(self, prompt: str) -> str:
        future = asyncio.get_event_loop().create_future()
        self.queue.append((prompt, future))

        if len(self.queue) >= self.batch_size:
            await self._flush()
        else:
            asyncio.get_event_loop().call_later(self.max_wait, lambda: asyncio.ensure_future(self._flush()))

        return await future

    async def _flush(self):
        batch = self.queue[:self.batch_size]
        self.queue = self.queue[self.batch_size:]

        prompts = [p for p, _ in batch]
        results = await asyncio.gather(*[llm_call(p) for p in prompts])

        for (_, future), result in zip(batch, results):
            future.set_result(result)
```

## Budget Alerts

```python
class BudgetMonitor:
    def __init__(self, daily_budget_usd: float = 10.0):
        self.daily_budget = daily_budget_usd
        self.daily_spend: float = 0.0

    def record(self, cost_usd: float):
        self.daily_spend += cost_usd
        if self.daily_spend >= self.daily_budget * 0.8:
            send_alert(f"AI spending at {self.daily_spend/self.daily_budget:.0%} of daily budget")
        if self.daily_spend >= self.daily_budget:
            raise BudgetExceededError("Daily AI budget exceeded")

    def can_afford(self, estimated_cost: float) -> bool:
        return self.daily_spend + estimated_cost <= self.daily_budget
```

## Graceful Degradation

```kotlin
// Android: fall back to cheaper model or cached response when budget is low
class AiRepository(private val api: AiApi) {
    suspend fun query(prompt: String): AiResponse {
        return try {
            api.chat(ChatRequest(prompt, model = "claude-sonnet-4-20250514"))
        } catch (e: BudgetExceededException) {
            // Fall back to cached FAQ or smaller model
            api.chat(ChatRequest(prompt, model = "claude-haiku-3-5-20241022"))
        }
    }
}
```

## Monitoring Dashboard Metrics

Track these metrics to control costs:
- **Tokens per request** (input/output separately)
- **Cost per user per day**
- **Cache hit rate** (target: >30%)
- **Model distribution** (% of requests per model tier)
- **Error rate** (failed requests waste budget on retries)
- **Latency** (fast responses = happier users = fewer retries)
