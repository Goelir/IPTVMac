import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/core/skip_marks.dart';
import 'package:iptvmac/core/user_data.dart';

import 'support.dart';

void main() {
  test('the intro is offered from its start until its end', () {
    const m = SkipMarks(introStart: 30, introEnd: 120);
    SkipOffer? at(double p) => SkipLogic.offer(m, position: p, duration: 2700);
    expect(at(10), isNull); // the cold open: before the intro
    expect(at(30), const SkipIntro(120));
    expect(at(119), isNull); // about to end: no button
    expect(at(300), isNull);
    expect(SkipLogic.offer(const SkipMarks(introEnd: 90), position: 0, duration: 2700), const SkipIntro(90)); // no start: from the first second
  });

  test('the credits are offered in the last stretch, whatever the length of the episode', () {
    const m = SkipMarks(creditsLen: 90);
    expect(SkipLogic.offer(m, position: 2000, duration: 2700), isNull);
    expect(SkipLogic.offer(m, position: 2610, duration: 2700), const SkipCredits());
    expect(SkipLogic.offer(m, position: 2699, duration: 2700), isNull); // the very end: nothing left to skip
    expect(SkipLogic.offer(m, position: 10, duration: 0), isNull); // duration unknown
    expect(SkipLogic.offer(const SkipMarks(creditsLen: 2), position: 2698, duration: 2700), isNull); // too short to be credits
    expect(SkipLogic.offer(const SkipMarks(creditsLen: 120), position: 1500 - 119, duration: 1500), const SkipCredits());
    expect(SkipLogic.offer(const SkipMarks(creditsLen: 120), position: 1500 - 200, duration: 1500), isNull);
    expect(SkipLogic.offer(const SkipMarks(introEnd: 2000), position: 100, duration: 2700), isNull); // an intro end beyond the middle is ignored
  });

  test('marks are accepted only where they make sense', () {
    var m = const SkipMarks();
    expect(SkipLogic.markIntroEnd(m, position: 1, duration: 2700), isNull); // an intro must have some length
    m = SkipLogic.markIntroEnd(m, position: 95, duration: 2700)!;
    expect(m.introEnd, 95);
    expect(SkipLogic.markIntroEnd(m, position: 2000, duration: 2700), isNull); // past the middle
    final s = SkipLogic.markIntroStart(m, position: 20, duration: 2700)!;
    expect((s.introStart, s.introEnd), (20, 95));
    expect(SkipLogic.markIntroStart(s, position: 100, duration: 2700)!.introEnd, isNull); // the end was before the new start: dropped
    expect(SkipLogic.markIntroStart(s, position: 0.4, duration: 2700)!.introStart, isNull); // at the very start = no start
    expect(SkipLogic.markCredits(m, position: 1000, duration: 2700), isNull); // credits are not in the first half
    expect(SkipLogic.markCredits(m, position: 2699, duration: 2700), isNull);
    expect(SkipLogic.markCredits(m, position: 2600, duration: 2700)!.creditsLen, 100);
  });

  test('marks are saved per series, empty marks remove the row, and they go with their playlist', () {
    final (db, a) = makeDB();
    SkipMarks load(String sid) => db.read((d) => UserData.skipMarks(d, accountId: a, seriesId: sid));
    expect(load('9').isEmpty, isTrue);
    db.write((d) {
      UserData.saveSkipMarks(d, accountId: a, seriesId: '9', marks: const SkipMarks(introStart: 12, introEnd: 80, creditsLen: 70));
      UserData.saveSkipMarks(d, accountId: a, seriesId: '10', marks: const SkipMarks(introEnd: 50));
    });
    expect(load('9'), const SkipMarks(introStart: 12, introEnd: 80, creditsLen: 70));
    expect(load('10'), const SkipMarks(introEnd: 50));
    db.write((d) => UserData.saveSkipMarks(d, accountId: a, seriesId: '9', marks: const SkipMarks(introEnd: 85))); // an update replaces all three
    expect(load('9'), const SkipMarks(introEnd: 85));
    db.write((d) => UserData.saveSkipMarks(d, accountId: a, seriesId: '9', marks: const SkipMarks()));
    expect(load('9').isEmpty, isTrue);
    db.write((d) => d.execute('DELETE FROM account WHERE id = ?', [a]));
    expect(count(db, 'SELECT COUNT(*) FROM series_marks'), 0);
  });
}
