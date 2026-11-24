import asyncio
import base64
from datetime import datetime, timezone
import logging
from typing import Optional
from zoneinfo import ZoneInfo

from sqlalchemy import select
from app.db.session import AsyncSessionLocal
from app.models.device_token import DeviceToken
from app.models.reminder import EncryptedReminder
from app.models.voice_assistant import Reminder, TaskLifecycleState
from app.services.fcm_service import fcm_push_service

logger = logging.getLogger(__name__)


class ReminderScheduler:
    """High-concurrency background reminder lifecycle processor.

    - Uses `SELECT ... FOR UPDATE SKIP LOCKED` so multiple uvicorn workers never
      double-process or double-notify the same reminder.
    - Enforces strict tenant isolation: dispatches FCM push ONLY to `DeviceToken` rows
      owned by `reminder.user_id` (zero cross-tenant fallback).
    - Enforces Zero-Touch Auto-Completion: once due/processed, both `Reminder` (`state='completed'`)
      and `EncryptedReminder` (`is_completed=True, notification_sent=True`) transition
      strictly and irreversibly to `completed`.
    """

    def __init__(self, interval_seconds: int = 30):
        self.interval_seconds = interval_seconds
        self._task: Optional[asyncio.Task] = None
        self._running: bool = False

    def start(self) -> None:
        if self._running:
            return
        self._running = True
        self._task = asyncio.create_task(self._run_loop())
        logger.info(
            "[ReminderScheduler] Started zero-touch auto-completion loop (interval: %ss).",
            self.interval_seconds,
        )

    async def stop(self) -> None:
        self._running = False
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        logger.info("[ReminderScheduler] Stopped background loop.")

    async def _run_loop(self) -> None:
        await asyncio.sleep(5)
        while self._running:
            try:
                await self.check_due_reminders()
            except Exception as e:
                logger.error("[ReminderScheduler] Error during tick: %s", e, exc_info=True)

            try:
                await asyncio.sleep(self.interval_seconds)
            except asyncio.CancelledError:
                break

    async def check_due_reminders(self) -> int:
        """Atomically claims due reminders, dispatches tenant-scoped pushes, and irreversibly marks `completed`."""
        now = datetime.now(timezone.utc)
        completed_count = 0

        async with AsyncSessionLocal() as db:
            try:
                # 1. Auto-complete due assistant `Reminder` rows (`scheduled` -> `completed`)
                voice_stmt = (
                    select(Reminder)
                    .where(
                        Reminder.state == TaskLifecycleState.SCHEDULED.value,
                        Reminder.reminder_time <= now,
                    )
                    .with_for_update(skip_locked=True)
                    .limit(100)
                )
                voice_res = await db.execute(voice_stmt)
                due_voice_reminders = voice_res.scalars().all()
                for vr in due_voice_reminders:
                    vr.mark_completed(now)
                    completed_count += 1

                # 2. Claim due `EncryptedReminder` rows with row-level lock (`SKIP LOCKED`)
                enc_stmt = (
                    select(EncryptedReminder)
                    .where(
                        EncryptedReminder.due_at <= now,
                        EncryptedReminder.is_completed.is_(False),
                        EncryptedReminder.deleted_at.is_(None),
                    )
                    .with_for_update(skip_locked=True)
                    .limit(100)
                )
                result = await db.execute(enc_stmt)
                due_reminders = result.scalars().all()

                for reminder in due_reminders:
                    reminder_title = "Scheduled Reminder"
                    if reminder.ciphertext:
                        try:
                            decoded = (
                                base64.b64decode(reminder.ciphertext)
                                .decode("utf-8")
                                .strip()
                            )
                            if decoded:
                                reminder_title = decoded
                        except Exception:
                            pass

                    # STRICT TENANT SCOPING: query ONLY device tokens belonging to `reminder.user_id`
                    if not reminder.notification_sent:
                        token_stmt = select(DeviceToken.token).where(
                            DeviceToken.user_id == reminder.user_id
                        )
                        token_res = await db.execute(token_stmt)
                        tokens = list(token_res.scalars().all())

                        if tokens:
                            due_body = "Scheduled alarm from Pingo"
                            if reminder.due_at:
                                try:
                                    dhaka_dt = reminder.due_at.astimezone(
                                        ZoneInfo("Asia/Dhaka")
                                    )
                                    due_body = dhaka_dt.strftime(
                                        "%I:%M %p · %d %b"
                                    ).lstrip("0")
                                except Exception:
                                    due_body = reminder.due_at.strftime(
                                        "%H:%M UTC · %d %b"
                                    )

                            for token in tokens:
                                await fcm_push_service.send_reminder_push(
                                    token=token,
                                    title=reminder_title,
                                    body=due_body,
                                    data={
                                        "reminder_id": str(reminder.id),
                                        "title": reminder_title,
                                        "body": due_body,
                                        "due_at": (
                                            reminder.due_at.isoformat()
                                            if reminder.due_at
                                            else ""
                                        ),
                                        "state": "completed",
                                    },
                                )

                    # Zero-Touch Irreversible Auto-Completion
                    reminder.notification_sent = True
                    reminder.is_completed = True
                    reminder.updated_at = now
                    completed_count += 1

                if due_voice_reminders or due_reminders:
                    await db.commit()
                    logger.info(
                        "[ReminderScheduler] Auto-completed %d due reminder record(s).",
                        completed_count,
                    )
            except Exception as e:
                await db.rollback()
                logger.error(
                    "[ReminderScheduler] Database error during reminder check: %s", e
                )
                raise

        return completed_count


reminder_scheduler = ReminderScheduler()
