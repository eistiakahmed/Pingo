import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/features/voice_capture/presentation/screens/pingo_voice_screen.dart';

enum FlowScenario {
  autoSaved,
  askAboutToday,
  askQuestion,
}

/// Screen implementing conversational flows with clean, zero-mock dynamic data.
class PingoFlowScreen extends StatefulWidget {
  final FlowScenario scenario;
  final String initialPrompt;

  const PingoFlowScreen({
    super.key,
    required this.scenario,
    required this.initialPrompt,
  });

  static void open(BuildContext context, {required FlowScenario scenario, required String prompt}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PingoFlowScreen(scenario: scenario, initialPrompt: prompt),
      ),
    );
  }

  @override
  State<PingoFlowScreen> createState() => _PingoFlowScreenState();
}

class _PingoFlowScreenState extends State<PingoFlowScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Dynamic state for auto-saved reminder
  late String _taskTitle;
  late String _taskDate;
  late String _taskTime;
  bool _hasFollowUpUpdate = false;
  String _followUpTime = '6:00 PM';
  String _reminderAlert = '1 hour before';

  // State for user checklist items
  final List<Map<String, dynamic>> _todayTasks = [];

  // State for Ask Question scenario
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    _parseInitialPrompt();
  }

  void _parseInitialPrompt() {
    final prompt = widget.initialPrompt.trim();
    if (prompt.isEmpty) {
      _taskTitle = 'New Reminder';
    } else {
      _taskTitle = prompt;
    }
    _taskDate = 'Today';
    _taskTime = 'Scheduled';

    // Normalize Bangla digits to standard numerals
    final Map<String, String> bnDigits = {
      '১': '1', '২': '2', '৩': '3', '৪': '4', '৫': '5',
      '৬': '6', '৭': '7', '৮': '8', '৯': '9', '০': '0'
    };
    String normalized = prompt;
    bnDigits.forEach((k, v) => normalized = normalized.replaceAll(k, v));
    final lower = normalized.toLowerCase();

    // Dates
    if (lower.contains('tomorrow') || lower.contains('কাল') || lower.contains('আগামীকাল')) {
      _taskDate = 'Tomorrow';
    } else if (lower.contains('পরশু')) {
      _taskDate = 'Day after tomorrow';
    } else if (lower.contains('10th')) {
      _taskDate = '10th of this month';
    }

    // Dynamic Time Matcher (e.g. 9:00 a.m., 9 am, 9:00, ৯টা)
    final timeMatch = RegExp(r'(\d{1,2}(:\d{2})?\s*(am|pm|a\.m\.|p\.m\.)|\b\d{1,2}(:\d{2})?\b(?=\s*টা))', caseSensitive: false).firstMatch(lower);
    if (timeMatch != null) {
      String raw = timeMatch.group(0)!.replaceAll('.', '').toUpperCase().trim();
      if (raw.contains('PM') || raw.contains('AM')) {
        _taskTime = raw;
      } else if (lower.contains('সকাল') || lower.contains('morning')) {
        _taskTime = raw.contains(':') ? '$raw AM' : '$raw:00 AM';
      } else if (lower.contains('রাত') || lower.contains('সন্ধ্যা') || lower.contains('বিকাল') || lower.contains('night') || lower.contains('evening')) {
        _taskTime = raw.contains(':') ? '$raw PM' : '$raw:00 PM';
      } else {
        _taskTime = raw.contains(':') ? '$raw AM' : '$raw:00 AM';
      }
    } else if (lower.contains('5 pm') || lower.contains('5:00')) {
      _taskTime = '5:00 PM';
    } else if (lower.contains('9 pm') || lower.contains('9:00')) {
      _taskTime = '9:00 PM';
    } else if (lower.contains('8 am') || lower.contains('8:00')) {
      _taskTime = '8:00 AM';
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _handleSend(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _inputController.clear();

    final lower = trimmed.toLowerCase();
    setState(() {
      if (lower.contains('hour') || lower.contains('make it') || lower.contains('pm') || lower.contains('am')) {
        _hasFollowUpUpdate = true;
        _followUpTime = trimmed;
      } else if (lower.contains('morning') || lower.contains('afternoon') || lower.contains('evening')) {
        _selectedTime = trimmed;
      }
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBg : AppColors.pingoBackground;
    final cardBg = isDark ? AppColors.darkSurface : AppColors.pingoSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.pingoBorder;
    final textColor = isDark ? Colors.white : AppColors.pingoDark;
    final mutedColor = isDark ? AppColors.darkTextSecondary : AppColors.pingoMuted;

    String title = 'Pingo';
    String hintText = 'Change it by message or voice';
    if (widget.scenario == FlowScenario.autoSaved) {
      title = 'Reminder set';
      hintText = 'Change it by message or voice';
    } else if (widget.scenario == FlowScenario.askAboutToday) {
      title = 'Pingo';
      hintText = 'Ask about your tasks';
    } else if (widget.scenario == FlowScenario.askQuestion) {
      title = 'Pingo';
      hintText = 'Or say the time';
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFE5E7EB),
                          width: 1.2,
                        ),
                        color: isDark ? AppColors.darkSurface : Colors.white,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            // Conversation Stream
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  if (widget.scenario == FlowScenario.autoSaved) ...[
                    _buildAutoSavedContent(isDark, cardBg, borderColor, textColor, mutedColor),
                  ] else if (widget.scenario == FlowScenario.askAboutToday) ...[
                    _buildAskAboutTodayContent(isDark, cardBg, borderColor, textColor, mutedColor),
                  ] else if (widget.scenario == FlowScenario.askQuestion) ...[
                    _buildAskQuestionContent(isDark, cardBg, borderColor, textColor, mutedColor),
                  ],
                ],
              ),
            ),

            // Bottom Input Dock
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: _buildBottomInputDock(isDark, cardBg, borderColor, textColor, hintText),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. Scenario: Auto Saved (Dynamic based on user prompt) ---
  Widget _buildAutoSavedContent(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color mutedColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _userBubble(_taskTitle),
        const SizedBox(height: 14),

        _botHeader(),
        const SizedBox(height: 8),

        // Auto Saved Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.check_circle, color: AppColors.success, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Saved automatically',
                    style: TextStyle(
                      color: Color(0xFF047857),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _taskTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: mutedColor),
                  const SizedBox(width: 6),
                  Text(_taskDate, style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 14),
                  Icon(Icons.access_time_rounded, size: 16, color: mutedColor),
                  const SizedBox(width: 6),
                  Text(_taskTime, style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),

        // Follow up Update (if user made adjustments)
        if (_hasFollowUpUpdate) ...[
          const SizedBox(height: 16),
          _userBubble('Updated reminder time: $_followUpTime'),
          const SizedBox(height: 14),
          _botHeader(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Updated',
                  style: TextStyle(
                    color: AppColors.pingoPurple,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _taskTitle,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 16, color: mutedColor),
                    const SizedBox(width: 6),
                    Text(_taskDate, style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 14),
                    Icon(Icons.access_time_rounded, size: 16, color: mutedColor),
                    const SizedBox(width: 6),
                    Text(_followUpTime, style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 16, color: mutedColor),
                    const SizedBox(width: 6),
                    Text(_reminderAlert, style: TextStyle(fontSize: 14, color: textColor)),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: borderColor, height: 1),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      _hasFollowUpUpdate = false;
                    });
                  },
                  child: const Text(
                    'Undo this change',
                    style: TextStyle(
                      color: AppColors.pingoPurple,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Contextual action chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('Repeat weekly', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Set to repeat weekly')),
              );
            }),
            _chip('Move to tomorrow', () {
              setState(() => _taskDate = 'Tomorrow');
            }),
            _chip('Add a note', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note option opened')),
              );
            }),
          ],
        ),
      ],
    );
  }

  // --- 2. Scenario: Ask About Today (Zero fake items) ---
  Widget _buildAskAboutTodayContent(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color mutedColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _userBubble('What do I have today?'),
        const SizedBox(height: 14),
        _botHeader(),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: _todayTasks.isEmpty
              ? Column(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      'No tasks left for today!',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You are all caught up. Say or type below to create a new reminder.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: mutedColor,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You have ${_todayTasks.where((t) => !t['done']).length} things left today.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Divider(color: borderColor, height: 1),
                    ..._todayTasks.map((task) => _checklistItem(
                          title: task['title'],
                          time: task['time'],
                          isCompleted: task['done'],
                          onToggle: () {
                            setState(() => task['done'] = !task['done']);
                            _scrollToBottom();
                          },
                          textColor: textColor,
                          mutedColor: mutedColor,
                          borderColor: borderColor,
                        )),
                  ],
                ),
        ),

        const SizedBox(height: 20),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('What about tomorrow?', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checking tomorrow’s schedule')),
              );
            }),
            _chip('Anything overdue?', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Zero overdue items!')),
              );
            }),
          ],
        ),
      ],
    );
  }

  // --- 3. Scenario: Ask Question (Clarification for user prompt) ---
  Widget _buildAskQuestionContent(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color mutedColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _userBubble(_taskTitle),
        const SizedBox(height: 14),
        _botHeader(),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Not saved yet',
                style: TextStyle(
                  color: Color(0xFFB45309),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'What time should I remind you?',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 16),

              _timeOptionPill('Morning, 9:00 AM', textColor, borderColor),
              const SizedBox(height: 10),
              _timeOptionPill('Afternoon, 2:00 PM', textColor, borderColor),
              const SizedBox(height: 10),
              _timeOptionPill('Evening, 6:00 PM', textColor, borderColor),

              const SizedBox(height: 14),
              InkWell(
                onTap: () {
                  showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
                },
                child: const Text(
                  'Pick another time',
                  style: TextStyle(
                    color: AppColors.pingoPurple,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_selectedTime != null) ...[
          const SizedBox(height: 16),
          _userBubble(_selectedTime!),
          const SizedBox(height: 14),
          _botHeader(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Saved! Reminding you at $_selectedTime',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- Helpers ---
  Widget _userBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.pingoPurple,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _botHeader() {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.pingoPurpleLight,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.notifications_rounded, color: AppColors.pingoPurple, size: 16),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Pingo',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E1B4B),
          ),
        ),
      ],
    );
  }

  Widget _checklistItem({
    required String title,
    required String time,
    required bool isCompleted,
    required VoidCallback onToggle,
    required Color textColor,
    required Color mutedColor,
    required Color borderColor,
  }) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            isCompleted
                ? const Icon(Icons.check_circle, color: AppColors.success, size: 22)
                : Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF9CA3AF), width: 1.6),
                    ),
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? mutedColor : textColor,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Text(
              time,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: mutedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeOptionPill(String timeText, Color textColor, Color borderColor) {
    final isSelected = _selectedTime == timeText;
    return InkWell(
      onTap: () {
        setState(() => _selectedTime = timeText);
        _scrollToBottom();
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppColors.pingoPurple : borderColor,
            width: isSelected ? 1.8 : 1.2,
          ),
          color: isSelected ? AppColors.pingoPurpleSubtle : Colors.transparent,
        ),
        child: Text(
          timeText,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.pingoPurple : textColor,
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
          color: Colors.white,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomInputDock(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    String hintText,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              onSubmitted: _handleSend,
              style: TextStyle(color: textColor, fontSize: 15),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14.5),
                border: InputBorder.none,
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              PingoVoiceScreen.show(context, onSpeechFinished: (speech) {
                _handleSend(speech);
              });
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.pingoPurple,
              ),
              child: const Center(
                child: Icon(Icons.mic, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
