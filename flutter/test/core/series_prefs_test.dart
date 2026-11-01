import 'package:flutter_test/flutter_test.dart';
import 'package:iptvmac/core/series_prefs.dart';
import 'package:iptvmac/core/user_data.dart';
import 'package:iptvmac/player/series_prefs_keeper.dart';

import 'support.dart';

typedef T = ({int id, String? lang, String? title});

void main() {
  test('a saved language finds its track in the next episode', () {
    final tracks = <T>[(id: 1, lang: 'eng', title: null), (id: 2, lang: 'heb', title: 'Hebrew'), (id: 3, lang: null, title: 'Commentary')];
    expect(SeriesPrefsLogic.action(const SubtitleLanguage('heb'), tracks), const SubtitleAction.track(2));
    expect(SeriesPrefsLogic.action(const SubtitleLanguage('HEB'), tracks), const SubtitleAction.track(2)); // case does not matter
    expect(SeriesPrefsLogic.action(const SubtitleLanguage('commentary'), tracks), const SubtitleAction.track(3)); // a track without a language: by its title
    expect(SeriesPrefsLogic.action(const SubtitleLanguage('fra'), tracks), isNull); // not in this episode: the default stays
    expect(SeriesPrefsLogic.action(SubtitleChoice.off, tracks), const SubtitleAction.off());
    expect(SeriesPrefsLogic.action(null, tracks), isNull);
  });

  test('the choice of a track is its language or its title', () {
    expect(SubtitleChoice.of(lang: ' HEB ', title: 'x'), const SubtitleLanguage('heb'));
    expect(SubtitleChoice.of(title: 'Commentary'), const SubtitleLanguage('commentary'));
    expect(SubtitleChoice.of(lang: ''), isNull);
  });

  test('prefs are saved per series, empty prefs remove the row, and they go with their playlist', () {
    final (db, a) = makeDB();
    SeriesPrefs load(String s) => db.read((d) => UserData.seriesPrefs(d, accountId: a, seriesId: s));
    expect(load('9').isEmpty, isTrue);
    db.write((d) {
      UserData.saveSeriesPrefs(d, accountId: a, seriesId: '9', prefs: const SeriesPrefs(speed: 1.5, subtitle: SubtitleLanguage('heb')));
      UserData.saveSeriesPrefs(d, accountId: a, seriesId: '10', prefs: const SeriesPrefs(subtitle: SubtitleChoice.off));
    });
    expect(load('9'), const SeriesPrefs(speed: 1.5, subtitle: SubtitleLanguage('heb')));
    expect(load('10'), const SeriesPrefs(subtitle: SubtitleChoice.off)); // "off" is a choice, not "no choice"
    db.write((d) => UserData.saveSeriesPrefs(d, accountId: a, seriesId: '9', prefs: const SeriesPrefs(speed: 2)));
    expect(load('9'), const SeriesPrefs(speed: 2));
    db.write((d) => UserData.saveSeriesPrefs(d, accountId: a, seriesId: '9', prefs: const SeriesPrefs()));
    expect(load('9').isEmpty, isTrue);
    db.write((d) => d.execute('DELETE FROM account WHERE id = ?', [a]));
    expect(count(db, 'SELECT COUNT(*) FROM series_prefs'), 0);
  });

  test('the keeper applies the saved speed and subtitle once and saves the user\'s changes', () {
    final saved = <SeriesPrefs>[];
    final k = SeriesPrefsKeeper(prefs: const SeriesPrefs(speed: 1.5, subtitle: SubtitleLanguage('heb')), save: saved.add);
    expect(k.speed, 1.5);
    final tracks = <T>[(id: 1, lang: 'eng', title: null), (id: 2, lang: 'heb', title: null)];
    expect(k.subtitleToApply(const []), isNull); // the tracks are not there yet: wait
    expect(k.subtitleToApply(tracks), const SubtitleAction.track(2));
    expect(k.subtitleToApply(tracks), isNull); // only once per episode
    k.speedChanged(2);
    expect((saved.last.speed, k.speed), (2, 2));
    k.speedChanged(1);
    expect((saved.last.speed, k.speed), (null, 1)); // normal speed is "no choice"
    k.subtitleChosen(lang: 'eng');
    expect(saved.last.subtitle, const SubtitleLanguage('eng'));
    k.subtitleChosen(off: true);
    expect(saved.last.subtitle, SubtitleChoice.off);
  });

  test('a choice made by the user is not overridden by the saved one', () {
    final k = SeriesPrefsKeeper(prefs: const SeriesPrefs(subtitle: SubtitleLanguage('heb')), save: (_) {});
    k.subtitleChosen(lang: 'eng'); // before the tracks were listed
    expect(k.subtitleToApply(<T>[(id: 1, lang: 'eng', title: null), (id: 2, lang: 'heb', title: null)]), isNull);
  });
}
