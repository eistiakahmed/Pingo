/// Service computing dynamic, real-time context-aware prompt suggestions
/// based on the temporal cycle, pending workload, and active language locale.
class ContextSuggestionService {
  static final ContextSuggestionService instance = ContextSuggestionService._internal();
  ContextSuggestionService._internal();

  List<String> getSuggestions({
    required String language, // 'bn' or 'en'
    required int pendingTasksCount,
    required int storedDocsCount,
  }) {
    final now = DateTime.now();
    final hour = now.hour;
    final isBangla = language == 'bn';

    final List<String> suggestions = [];

    // 1. Time-of-Day Dynamic Suggestion
    if (hour >= 5 && hour < 12) {
      // Morning
      if (pendingTasksCount > 0) {
        suggestions.add(isBangla
            ? 'আজকের $pendingTasksCount টি শিডিউল করা কাজ দেখাও'
            : "Review today's $pendingTasksCount scheduled tasks");
      } else {
        suggestions.add(isBangla
            ? 'আজকের দিনের জন্য গুরুত্বপূর্ণ রিমাইন্ডার সেট করো'
            : 'Plan my key priorities for today');
      }
      suggestions.add(isBangla
          ? 'সকাল ৯:৩০ এ মিটিং রিমাইন্ডার'
          : 'Remind me of 9:30 AM team sync');
    } else if (hour >= 12 && hour < 17) {
      // Afternoon
      if (pendingTasksCount > 0) {
        suggestions.add(isBangla
            ? 'আজকের বাকি কাজগুলো দেখাও'
            : "Check remaining tasks for today");
      } else {
        suggestions.add(isBangla
            ? 'বিকালের মিটিং বা কাজের রিমাইন্ডার যোগ করো'
            : 'Add an afternoon follow-up reminder');
      }
      suggestions.add(isBangla
          ? 'বিকাল ৫টায় জিম রিমাইন্ডার'
          : 'Remind me at 5:00 PM for gym');
    } else if (hour >= 17 && hour < 22) {
      // Evening
      suggestions.add(isBangla
          ? 'আগামীকালের শিডিউলে কী আছে?'
          : "What is on my schedule for tomorrow?");
      suggestions.add(isBangla
          ? 'রাত ৯টায় মেডিসিনের রিমাইন্ডার'
          : 'Set medicine reminder for 9:00 PM');
    } else {
      // Night (22:00 - 05:00)
      suggestions.add(isBangla
          ? 'কাল সকাল ৭টায় এলার্ম দাও'
          : 'Set wake-up alarm for 7:00 AM');
      suggestions.add(isBangla
          ? 'কালকের প্রথম মিটিং কখন?'
          : "When is my first meeting tomorrow?");
    }

    // 2. Document & Data Management Suggestion
    if (storedDocsCount > 0) {
      suggestions.add(isBangla
          ? 'আমার সংরক্ষিত ডকুমেন্টস দেখাও'
          : 'Show my stored documents');
    } else {
      suggestions.add(isBangla
          ? 'পাসপোর্ট বা এনআইডি সুরক্ষিত সংরক্ষণ করো'
          : 'Attach passport or ID to secure memory');
    }

    // 3. System Diagnostic Alert Check
    suggestions.add(isBangla
        ? 'নোটিফিকেশন ও এলার্ট ইঞ্জিন টেস্ট করো'
        : 'Test instant alert notification');

    return suggestions;
  }

  String getGreetingHeader({required String language}) {
    final hour = DateTime.now().hour;
    final isBangla = language == 'bn';

    if (hour >= 5 && hour < 12) {
      return isBangla ? 'শুভ সকাল' : 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return isBangla ? 'শুভ দুপুর' : 'Good afternoon';
    } else if (hour >= 17 && hour < 22) {
      return isBangla ? 'শুভ সন্ধ্যা' : 'Good evening';
    } else {
      return isBangla ? 'শুভ রাত্রি' : 'Good evening';
    }
  }
}
