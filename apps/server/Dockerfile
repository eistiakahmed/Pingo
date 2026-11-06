FROM python:3.12-slim AS base

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Security: non-root execution
RUN groupadd -g 1000 pingo && \
    useradd -u 1000 -g pingo -m -s /bin/bash pingo

WORKDIR /app

# Copy dependency specifications
COPY apps/server/requirements.txt ./
COPY packages/e2ee_py /packages/e2ee_py

# Install dependencies and link local packages
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir -e /packages/e2ee_py

# Copy server code
COPY apps/server /app

# Set ownership to non-root user
RUN chown -R pingo:pingo /app /packages/e2ee_py

USER pingo

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PORT=8000 \
    PYTHONPATH="/app:/packages/e2ee_py"

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
