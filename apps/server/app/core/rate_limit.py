import time
from typing import Dict, List
from fastapi import Request, status
from app.core.exceptions import AppException


class InMemoryRateLimiter:
    """
    Sliding window in-memory rate limiter per client IP with bounded memory
    and automatic stale key eviction.
    """

    def __init__(
        self,
        requests_per_minute: int = 20,
        max_tracked_clients: int = 10_000,
        trust_proxy_headers: bool = False,
    ):
        self.requests_per_minute = requests_per_minute
        self.window_seconds = 60.0
        self.max_tracked_clients = max_tracked_clients
        self.trust_proxy_headers = trust_proxy_headers
        self.clients: Dict[str, List[float]] = {}
        self._last_pruned: float = time.time()

    def _extract_ip(self, request: Request) -> str:
        """Extracts client IP, defaulting to socket host to prevent IP spoofing."""
        if self.trust_proxy_headers:
            forwarded = request.headers.get("X-Forwarded-For")
            if forwarded:
                return forwarded.split(",")[0].strip()
        return request.client.host if request.client else "127.0.0.1"

    def _prune_stale(self, now: float) -> None:
        """Prunes all IP histories older than the sliding window to bound memory."""
        cutoff = now - self.window_seconds
        stale_keys = [
            ip for ip, timestamps in self.clients.items()
            if not timestamps or timestamps[-1] <= cutoff
        ]
        for ip in stale_keys:
            del self.clients[ip]
        self._last_pruned = now

    def check(self, request: Request) -> None:
        now = time.time()
        client_ip = self._extract_ip(request)
        cutoff = now - self.window_seconds

        # Periodically prune stale entries every 60s or when dict hits max size
        if (now - self._last_pruned > self.window_seconds) or (len(self.clients) >= self.max_tracked_clients):
            self._prune_stale(now)

        history = self.clients.get(client_ip, [])
        # Filter timestamps within current window
        valid_history = [ts for ts in history if ts > cutoff]

        if len(valid_history) >= self.requests_per_minute:
            raise AppException(
                title="Rate Limit Exceeded",
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail=f"Too many requests. Limit is {self.requests_per_minute} requests per minute.",
                type_url="https://api.pingo.app/errors/rate-limit-exceeded",
            )

        valid_history.append(now)
        self.clients[client_ip] = valid_history


ai_rate_limiter = InMemoryRateLimiter(requests_per_minute=20)
auth_rate_limiter = InMemoryRateLimiter(requests_per_minute=10)


async def check_ai_rate_limit(request: Request) -> None:
    """Dependency enforcing rate limits on AI natural language endpoints."""
    ai_rate_limiter.check(request)


async def check_auth_rate_limit(request: Request) -> None:
    """Dependency enforcing rate limits on authentication endpoints."""
    auth_rate_limiter.check(request)
