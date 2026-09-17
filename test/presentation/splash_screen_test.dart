import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/presentation/screens/splash_screen.dart';

void main() {
  group('SplashScreen — VANTA Labz Branding & Animated Loading', () {
    testWidgets(
      'renderiza logo da VANTA Labz, barra de progresso e texto de autoria',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: SplashScreen(duration: Duration(seconds: 5))),
        );

        // Renderiza primeiro frame da animação
        await tester.pump();

        // Verifica imagem ou fallback de texto da logo
        expect(find.byType(Image), findsOneWidget);

        // Verifica indicador de carregamento
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        // Verifica mensagem obrigatória de autoria em inglês
        expect(find.text('Developed by VANTA Labz'), findsOneWidget);

        // Avança a animação
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 700));
      },
    );

    testWidgets(
      'executa callback onFinished após a expiração do tempo de loading',
      (tester) async {
        bool finished = false;

        await tester.pumpWidget(
          MaterialApp(
            home: SplashScreen(
              duration: const Duration(milliseconds: 500),
              onFinished: () {
                finished = true;
              },
            ),
          ),
        );

        await tester.pump();
        expect(finished, isFalse);

        await tester.pump(const Duration(milliseconds: 600));
        expect(finished, isTrue);
      },
    );
  });
}
