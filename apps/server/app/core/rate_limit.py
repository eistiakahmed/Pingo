from collections import defaultdict
from datetime import datetime, timezone
import time
from typing import Dict, List
from fastapi import Request, status
from app.core.exceptions import AppException


class InMemoryRateLimiter:
    """Thread-safe sliding window in-memory rate limiter per client IP."""

    def __init__(self, requests_per_minute: int = 20):
        self.requests_per_minute = requests_per_minute
        self.window_seconds = 60
        self.clients: Dict[str, List[float]] = defaultdict(list)

    def check(self, request: Request) -> None:
        client_ip = (
            request.headers.get("X-Forwarded-For", "").split(",")[0].strip()
            or (request.client.host if request.client else "127.0.0.1")
        )
        now = time.time()
        cutoff = now - self.window_seconds

        # Clean old timestamps
        history = [ts for ts in self.clients[client_ip] if ts > cutoff]
        if len(history) >= self.requests_per_minute:
            raise AppException(
                title="Rate Limit Exceeded",
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Too many requests. Limit is {self.requests_per_minute} requests per minute.",
                type_url="https://api.pingo.app/errors/rate-limit-exceeded",
            )

        history.append(now)
        self.clients[client_ip] = history


ai_rate_limiter = InMemoryRateLimiter(requests_per_minute=20)


async def check_ai_rate_limit(request: Request) -> None:
    """Dependency enforcing rate limits on AI natural language endpoints."""
    ai_rate_limiter.check(request)

