import 'package:flutter/material.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/features/voice_capture/presentation/screens/pingo_voice_screen.dart';

enum FlowScenario {
  autoSaved,
  askAboutToday,
  askQuestion,
}

/// Screen implementing '2. Auto saved.png', '3. Ask about today.png', and '10. Ask a question.png'.
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

  // State for Auto Saved scenario
  bool _hasFollowUpUpdate = false;

  // State for Ask About Today scenario
  bool _bankCalled = false;
  bool _electricityPaid = false;
  bool _medicineMomTaken = false;

  // State for Ask Question scenario
  String? _selectedTime;

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
      if (lower.contains('bank') || lower.contains('called')) {
        _bankCalled = true;
      } else if (lower.contains('6') || lower.contains('hour') || lower.contains('make it')) {
        _hasFollowUpUpdate = true;
      } else if (lower.contains('morning') || lower.contains('9')) {
        _selectedTime = 'Morning, 9:00 AM';
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

  // --- 1. Scenario: Auto Saved (2. Auto saved.png) ---
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
        // User initial bubble
        _userBubble(widget.initialPrompt.isNotEmpty ? widget.initialPrompt : 'Doctor with Mom tomorrow at 5 PM'),
        const SizedBox(height: 14),

        // Bot Header
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
                'Doctor with Mom',
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
                  Text('Sat, Nov 7', style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 14),
                  Icon(Icons.access_time_rounded, size: 16, color: mutedColor),
                  const SizedBox(width: 6),
                  Text('5:00 PM', style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),

        // Follow up Update (if triggered)
        if (_hasFollowUpUpdate) ...[
          const SizedBox(height: 16),
          _userBubble('Make it 6 PM and remind me 1 hour before'),
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
                  'Doctor with Mom',
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
                    Text('Sat, Nov 7', style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500)),
                    const SizedBox(width: 14),
                    Icon(Icons.access_time_rounded, size: 16, color: mutedColor),
                    const SizedBox(width: 6),
                    Text('6:00 PM', style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 16, color: mutedColor),
                    const SizedBox(width: 6),
                    Text('1 hour before', style: TextStyle(fontSize: 14, color: textColor)),
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

        // Suggestion Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('Repeat weekly', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Set to repeat every Saturday')),
              );
            }),
            _chip('Move to Sunday', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Moved to Sunday, Nov 8')),
              );
            }),
            if (!_hasFollowUpUpdate)
              _chip('Make it 6 PM', () {
                setState(() => _hasFollowUpUpdate = true);
                _scrollToBottom();
              }),
            _chip('Add a note', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note added to reminder')),
              );
            }),
          ],
        ),
      ],
    );
  }

  // --- 2. Scenario: Ask About Today (3. Ask about today.png) ---
  Widget _buildAskAboutTodayContent(
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color mutedColor,
  ) {
    int remainingCount = 3 - (_bankCalled ? 1 : 0) - (_electricityPaid ? 1 : 0) - (_medicineMomTaken ? 1 : 0);
    if (remainingCount < 0) remainingCount = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _userBubble('What do I have today?'),
        const SizedBox(height: 14),
        _botHeader(),
        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have $remainingCount things left today.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 14),
              Divider(color: borderColor, height: 1),

              // Item 1: Blood pressure medicine (Already done)
              _checklistItem(
                title: 'Blood pressure medicine',
                time: '8:00 AM',
                isCompleted: true,
                onToggle: () {},
                textColor: textColor,
                mutedColor: mutedColor,
                borderColor: borderColor,
              ),

              // Item 2: Call the bank
              _checklistItem(
                title: 'Call the bank',
                time: '2:30 PM',
                isCompleted: _bankCalled,
                onToggle: () {
                  setState(() => _bankCalled = !_bankCalled);
                  _scrollToBottom();
                },
                textColor: textColor,
                mutedColor: mutedColor,
                borderColor: borderColor,
              ),

              // Item 3: Pay electricity bill
              _checklistItem(
                title: 'Pay electricity bill',
                time: '6:00 PM',
                isCompleted: _electricityPaid,
                onToggle: () {
                  setState(() => _electricityPaid = !_electricityPaid);
                  _scrollToBottom();
                },
                textColor: textColor,
                mutedColor: mutedColor,
                borderColor: borderColor,
              ),

              // Item 4: Medicine for Mom
              _checklistItem(
                title: 'Medicine for Mom',
                time: '9:00 PM',
                isCompleted: _medicineMomTaken,
                onToggle: () {
                  setState(() => _medicineMomTaken = !_medicineMomTaken);
                  _scrollToBottom();
                },
                textColor: textColor,
                mutedColor: mutedColor,
                borderColor: borderColor,
              ),
            ],
          ),
        ),

        // If user marked or called bank
        if (_bankCalled) ...[
          const SizedBox(height: 16),
          _userBubble('I called the bank'),
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
                  'Marked as done. $remainingCount left today.',
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

        const SizedBox(height: 20),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip('What about tomorrow?', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Showing tomorrow’s agenda')),
              );
            }),
            _chip('Anything overdue?', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No overdue items! All caught up.')),
              );
            }),
          ],
        ),
      ],
    );
  }

  // --- 3. Scenario: Ask Question (10. Ask a question.png) ---
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
        _userBubble('Call Rahim tomorrow'),
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
                  color: Color(0xFFB45309), // Amber
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'What time should I remind you tomorrow?',
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
