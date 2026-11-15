import asyncio
from datetime import datetime, timezone
import logging
from typing import Optional
from sqlalchemy import select, update
from app.db.session import AsyncSessionLocal
from app.models.device_token import DeviceToken
from app.models.reminder import EncryptedReminder
from app.services.fcm_service import fcm_push_service

logger = logging.getLogger(__name__)


class ReminderScheduler:
    def __init__(self, interval_seconds: int = 30):
        self.interval_seconds = interval_seconds
        self._task: Optional[asyncio.Task] = None
        self._running: bool = False

    def start(self) -> None:
        """Starts the background scheduler loop."""
        if self._running:
            return
        self._running = True
        self._task = asyncio.create_task(self._run_loop())
        logger.info(f"[ReminderScheduler] Started background loop (interval: {self.interval_seconds}s).")

    async def stop(self) -> None:
        """Stops the background scheduler loop cleanly."""
        self._running = False
        if self._task and not self._task.done():
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        logger.info("[ReminderScheduler] Stopped background loop.")

    async def _run_loop(self) -> None:
        # Give server a moment to complete startup before initial check
        await asyncio.sleep(5)

        while self._running:
            try:
                await self.check_due_reminders()
            except Exception as e:
                logger.error(f"[ReminderScheduler] Error during tick: {e}", exc_info=True)

            try:
                await asyncio.sleep(self.interval_seconds)
            except asyncio.CancelledError:
                break

    async def check_due_reminders(self) -> int:
        """Finds reminders that have reached their due timestamp and dispatches push notifications."""
        now = datetime.now(timezone.utc)
        notified_count = 0

        async with AsyncSessionLocal() as db:
            try:
                # 1. Fetch active un-notified reminders due at or before now
                stmt = (
                    select(EncryptedReminder)
                    .where(
                        EncryptedReminder.due_at <= now,
                        EncryptedReminder.is_completed.is_(False),
                        EncryptedReminder.notification_sent.is_(False),
                        EncryptedReminder.deleted_at.is_(None),
                    )
                    .limit(100)
                )
                result = await db.execute(stmt)
                due_reminders = result.scalars().all()

                if not due_reminders:
                    return 0

                logger.info(f"[ReminderScheduler] Found {len(due_reminders)} due reminder(s) to notify.")

                for reminder in due_reminders:
                    # 2. Fetch user's registered device tokens
                    token_stmt = select(DeviceToken.token).where(
                        DeviceToken.user_id == reminder.user_id
                    )
                    token_res = await db.execute(token_stmt)
                    tokens = token_res.scalars().all()

                    if tokens:
                        for token in tokens:
                            await fcm_push_service.send_reminder_push(
                                token=token,
                                title="Pingo",
                                body="You have a scheduled reminder right now.",
                                data={
                                    "reminder_id": str(reminder.id),
                                    "due_at": reminder.due_at.isoformat() if reminder.due_at else "",
                                    "ciphertext": reminder.ciphertext,
                                    "iv": reminder.iv,
                                    "auth_tag": reminder.auth_tag,
                                },
                            )

                    # 3. Mark reminder as notified
                    reminder.notification_sent = True
                    notified_count += 1

                await db.commit()
                logger.info(f"[ReminderScheduler] Dispatched notifications for {notified_count} reminder(s).")
            except Exception as e:
                await db.rollback()
                logger.error(f"[ReminderScheduler] Database error during reminder check: {e}")
                raise

        return notified_count


reminder_scheduler = ReminderScheduler()
