import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pingo_mobile/core/theme/app_colors.dart';
import 'package:pingo_mobile/features/home/domain/chat_message.dart';
import 'package:pingo_mobile/features/home/presentation/screens/pingo_home_screen.dart';
import 'package:pingo_mobile/features/home/presentation/widgets/chat_message_bubble.dart';
import 'package:pingo_mobile/features/home/presentation/widgets/tech_canvas_background.dart';
import 'package:pingo_mobile/features/voice_capture/data/voice_command_api_service.dart';

ThemeData _testTheme(PenguinPalette p) => ThemeData(
      brightness: p.brightness,
      scaffoldBackgroundColor: p.bg,
      useMaterial3: true,
    );

void main() {
  group('Penguin Adaptive Theme & UI Polish', () {
    test('PenguinPalette defines distinct matte Dark and soft Light tokens', () {
      const light = PenguinPalette.light;
      const dark = PenguinPalette.dark;

      expect(light.brightness, Brightness.light);
      expect(dark.brightness, Brightness.dark);
      expect(light.bg, const Color(0xFFF5F6F8));
      expect(dark.bg, const Color(0xFF0E0F12));
      expect(light.textPrimary, const Color(0xFF111216));
      expect(dark.textPrimary, const Color(0xFFFFFFFF));
      expect(light.bg, isNot(dark.bg));
    });

    testWidgets(
      'AppColors.of(context) and TechCanvasBackground adapt cleanly to Light and Dark modes without patterns',
      (tester) async {
        for (final palette in [PenguinPalette.light, PenguinPalette.dark]) {
          PenguinPalette? resolved;
          await tester.pumpWidget(
            MaterialApp(
              theme: _testTheme(palette),
              home: TechCanvasBackground(
                child: Builder(
                  builder: (context) {
                    resolved = AppColors.of(context);
                    return const SizedBox();
                  },
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(resolved, equals(palette));
          expect(
            find.descendant(
              of: find.byType(TechCanvasBackground),
              matching: find.byType(CustomPaint),
            ),
            findsNothing,
          );
          final coloredBox = tester.widget<ColoredBox>(
            find.descendant(
              of: find.byType(TechCanvasBackground),
              matching: find.byType(ColoredBox),
            ),
          );
          expect(coloredBox.color, palette.bg);
        }
      },
    );

    testWidgets(
      'StagedAttachmentPreviewCard renders visual-only 56x56 card without raw filename text',
      (tester) async {
        var removed = false;
        const item = StagedAttachmentPreviewItem(
          stagingId: 'stg_001',
          filename: 'secret_raw_prescription_2026.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 2048,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: _testTheme(PenguinPalette.light),
            home: Scaffold(
              body: StagedAttachmentPreviewCard(
                item: item,
                onRemove: () => removed = true,
              ),
            ),
          ),
        );

        // Raw filename must NOT be rendered in the visual-only card
        expect(find.text('secret_raw_prescription_2026.pdf'), findsNothing);
        expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        expect(removed, isTrue);
      },
    );

    testWidgets(
      'ChatMessageBubble renders cleanly in both Light and Dark modes with soft rounding',
      (tester) async {
        final userMsg = ChatMessage(
          id: 'u1',
          text: 'Remind me to pay electricity bill tomorrow at 9 AM',
          isUser: true,
          timestamp: DateTime(2026, 11, 25, 9, 0),
        );
        final botMsg = ChatMessage(
          id: 'b1',
          text: 'Scheduled your electricity bill reminder.',
          isUser: false,
          timestamp: DateTime(2026, 11, 25, 9, 0),
          reminderTitle: 'Pay electricity bill',
          reminderCategory: 'BILL',
          reminderDueAt: DateTime(2026, 11, 26, 9, 0),
        );

        for (final palette in [PenguinPalette.light, PenguinPalette.dark]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: _testTheme(palette),
              home: Scaffold(
                body: ListView(
                  children: [
                    ChatMessageBubble(message: userMsg),
                    ChatMessageBubble(message: botMsg),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text(userMsg.text), findsOneWidget);
          expect(find.text('BILL'), findsOneWidget);
          expect(find.text('Pay electricity bill'), findsOneWidget);
        }
      },
    );
  });
}
