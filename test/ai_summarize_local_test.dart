import 'package:covoiturage_etudiant/core/services/ai_summarize_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final s = AiSummarizeService.instance;

  test('texte long non ponctué est réellement raccourci', () {
    const texte =
        'slt franchement le cdd est arrivé avec 25 min de retard au point de rdv '
        'et en fait il nous a même pas prévenu du coup j ai raté mon examen à la fac '
        'et en plus il roulait très très vite sur l autoroute et genre il parlait au telephone '
        'tout le temps et franchement c est inadmissible je veux qu il soit sanctionné merci';
    final r = s.resumerLocal(texte);
    expect(r.texte.split(' ').length, lessThan(texte.split(' ').length * 0.8));
    expect(r.texte, contains('25 minutes'));
    expect(r.texte.toLowerCase(), isNot(contains('franchement')));
    expect(r.dejaConcis, isFalse);
    expect(r.texte, isNot(contains('pourév')));
    expect(r.texte, isNot(endsWith('et.')));
  });

  test('texte ponctué répétitif', () {
    const texte =
        'Le conducteur était en retard. Il était vraiment en retard de 30 minutes. '
        'La voiture était sale. Le conducteur était en retard et ne répondait pas au téléphone. '
        'Je demande un remboursement de 15 dt. Merci beaucoup.';
    final r = s.resumerLocal(texte);
    expect(r.texte.length, lessThan(texte.length));
    expect(r.texte, contains('15 DT'));
    expect(r.dejaConcis, isFalse);
  });

  test('texte court déjà concis : pas juste un point ajouté en silence', () {
    final r = s.resumerLocal('Le conducteur ne est pas venu');
    expect(r.dejaConcis, isTrue);
  });
}
