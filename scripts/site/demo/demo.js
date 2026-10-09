/* IPTVMac demo: an interactive mock of the app for the website. No dependencies, no network, no globals but IPTVDemo.
   IPTVDemo.mount(root, {lang, reducedMotion}) -> {destroy, setScene, setLang, setProgress, getState, setReducedMotion}
   Scenes: search, player, pip, playlists, languages. setProgress(scene, 0..1) fully drives each scripted timeline.
   UI strings: the 16 labels the mock shows come from the app's own Localizable.strings (31 languages). Hebrew, English and
   Arabic are reviewed by native speakers, the other 28 are AI-assisted and not native-reviewed. Titles are invented. */
(function (W, D) {
  'use strict';
var K=["tl","tm","ts","ca","cf","cc","cx","sp","sd","sn","sr","pip","sl","pa","er","mn","il"];
var T={"he":["שידור חי","סרטים","סדרות","הכול","מועדפים","המשך צפייה","סינון קטגוריות","חיפוש","מהירות ניגון","רגילה","מהירות רגילה","תמונה בתוך תמונה","טיימר שינה","כל הרשימות","לא נמצא כלום","%d ד׳","שפת הממשק"],"en":["Live","Movies","Series","All","Favorites","Continue watching","Filter categories","Search","Playback speed","Normal","Normal speed","Picture in Picture","Sleep timer","All playlists","Nothing found","%d min","Interface language"],"ar":["بث مباشر","أفلام","مسلسلات","الكل","المفضلة","متابعة المشاهدة","تصفية الفئات","بحث","سرعة التشغيل","عادية","السرعة العادية","صورة داخل صورة","مؤقت النوم","كل قوائم التشغيل","لم يتم العثور على شيء","%d د","لغة الواجهة"],"es":["En vivo","Películas","Series","Todas","Favoritos","Seguir viendo","Filtrar categorías","Buscar","Velocidad de reproducción","Normal","Velocidad normal","Imagen en imagen","Temporizador de apagado","Todas las listas","Sin resultados","%d min","Idioma de la interfaz"],"fr":["Direct","Films","Séries","Toutes","Favoris","Reprendre la lecture","Filtrer les catégories","Rechercher","Vitesse de lecture","Normale","Vitesse normale","Image dans l’image","Minuterie d’arrêt","Toutes les playlists","Aucun résultat","%d min","Langue de l’interface"],"de":["Live","Filme","Serien","Alle","Favoriten","Weiterschauen","Kategorien filtern","Suchen","Wiedergabegeschwindigkeit","Normal","Normale Geschwindigkeit","Bild-in-Bild","Einschlaftimer","Alle Playlists","Nichts gefunden","%d min","Sprache der Benutzeroberfläche"],"pt":["Ao vivo","Filmes","Séries","Todas","Favoritos","Continuar assistindo","Filtrar categorias","Buscar","Velocidade de reprodução","Normal","Velocidade normal","Picture in Picture","Timer de desligamento","Todas as playlists","Nada encontrado","%d min","Idioma da interface"],"it":["Diretta","Film","Serie TV","Tutte","Preferiti","Continua a guardare","Filtra categorie","Cerca","Velocità di riproduzione","Normale","Velocità normale","Picture in Picture","Timer di spegnimento","Tutte le playlist","Nessun risultato","%d min","Lingua dell’interfaccia"],"ru":["Эфир","Фильмы","Сериалы","Все","Избранное","Продолжить просмотр","Фильтр категорий","Поиск","Скорость воспроизведения","Обычная","Обычная скорость","Картинка в картинке","Таймер сна","Все плейлисты","Ничего не найдено","%d мин","Язык интерфейса"],"uk":["Ефір","Фільми","Серіали","Усі","Вибране","Продовжити перегляд","Фільтр категорій","Пошук","Швидкість відтворення","Звичайна","Звичайна швидкість","Картинка в картинці","Таймер сну","Усі плейлисти","Нічого не знайдено","%d хв","Мова інтерфейсу"],"pl":["Na żywo","Filmy","Seriale","Wszystkie","Ulubione","Kontynuuj oglądanie","Filtruj kategorie","Szukaj","Szybkość odtwarzania","Normalna","Normalna szybkość","Obraz w obrazie","Wyłącznik czasowy","Wszystkie playlisty","Nic nie znaleziono","%d min","Język interfejsu"],"ro":["În direct","Filme","Seriale","Toate","Favorite","Continuă vizionarea","Filtrează categoriile","Caută","Viteza de redare","Normală","Viteză normală","Imagine în imagine","Temporizator de oprire","Toate listele de redare","Nu s-a găsit nimic","%d min","Limba interfeței"],"bg":["На живо","Филми","Сериали","Всички","Любими","Продължи гледането","Филтриране на категориите","Търсене","Скорост на възпроизвеждане","Нормална","Нормална скорост","Картина в картината","Таймер за заспиване","Всички плейлисти","Няма намерени резултати","%d мин","Език на интерфейса"],"nl":["Live","Films","Series","Alle","Favorieten","Verder kijken","Categorieën filteren","Zoek","Afspeelsnelheid","Normaal","Normale snelheid","Beeld-in-beeld","Slaaptimer","Alle afspeellijsten","Niets gevonden","%d min","Taal van de interface"],"sv":["Direkt","Filmer","Serier","Alla","Favoriter","Fortsätt titta","Filtrera kategorier","Sök","Uppspelningshastighet","Normal","Normal hastighet","Bild i bild","Sovtimer","Alla spellistor","Inga resultat","%d min","Gränssnittsspråk"],"cs":["Živě","Filmy","Seriály","Vše","Oblíbené","Pokračovat ve sledování","Filtrovat kategorie","Hledat","Rychlost přehrávání","Normální","Normální rychlost","Obraz v obraze","Časovač vypnutí","Všechny playlisty","Nic nenalezeno","%d min","Jazyk rozhraní"],"hu":["Élő","Filmek","Sorozatok","Összes","Kedvencek","Nézés folytatása","Kategóriák szűrése","Keresés","Lejátszási sebesség","Normál","Normál sebesség","Kép a képben","Elalvásidőzítő","Összes lejátszási lista","Nincs találat","%d p","Felület nyelve"],"el":["Ζωντανά","Ταινίες","Σειρές","Όλα","Αγαπημένα","Συνέχεια προβολής","Φιλτράρισμα κατηγοριών","Αναζήτηση","Ταχύτητα αναπαραγωγής","Κανονική","Κανονική ταχύτητα","Εικόνα σε εικόνα","Χρονοδιακόπτης ύπνου","Όλες οι λίστες αναπαραγωγής","Δεν βρέθηκε τίποτα","%d λ.","Γλώσσα διεπαφής"],"sq":["Drejtpërdrejt","Filma","Seriale","Të gjitha","Të preferuarat","Vazhdo shikimin","Filtro kategoritë","Kërko","Shpejtësia e luajtjes","Normale","Shpejtësia normale","Figurë brenda figure","Kohëmatësi i gjumit","Të gjitha listat e luajtjes","Nuk u gjet asgjë","%d min","Gjuha e ndërfaqes"],"tr":["Canlı","Filmler","Diziler","Tümü","Favoriler","İzlemeye devam et","Kategorileri filtrele","Ara","Oynatma hızı","Normal","Normal hız","Pencere içinde pencere","Uyku zamanlayıcısı","Tüm oynatma listeleri","Hiçbir şey bulunamadı","%d dk","Arayüz dili"],"fa":["زنده","فیلم‌ها","سریال‌ها","همه","علاقه‌مندی‌ها","ادامهٔ تماشا","فیلتر دسته‌ها","جستجو","سرعت پخش","عادی","سرعت عادی","تصویر در تصویر","زمان‌سنج خواب","همهٔ فهرست‌های پخش","چیزی پیدا نشد","%d دقیقه","زبان رابط"],"ur":["لائیو","فلمیں","سیریز","سب","پسندیدہ","دیکھنا جاری رکھیں","زمرے فلٹر کریں","تلاش","پلے بیک کی رفتار","عام","عام رفتار","تصویر میں تصویر","سلیپ ٹائمر","تمام پلے لسٹس","کچھ نہیں ملا","%d منٹ","انٹرفیس کی زبان"],"hi":["लाइव","फ़िल्में","सीरीज़","सभी","पसंदीदा","देखना जारी रखें","श्रेणियाँ फ़िल्टर करें","खोजें","प्लेबैक गति","सामान्य","सामान्य गति","पिक्चर इन पिक्चर","स्लीप टाइमर","सभी प्लेलिस्ट","कुछ नहीं मिला","%d मि.","इंटरफ़ेस की भाषा"],"bn":["লাইভ","সিনেমা","সিরিজ","সব","প্রিয়","দেখা চালিয়ে যান","ক্যাটাগরি ফিল্টার করুন","অনুসন্ধান","প্লেব্যাকের গতি","স্বাভাবিক","স্বাভাবিক গতি","পিকচার ইন পিকচার","স্লিপ টাইমার","সব প্লেলিস্ট","কিছু পাওয়া যায়নি","%d মি.","ইন্টারফেসের ভাষা"],"id":["Langsung","Film","Serial","Semua","Favorit","Lanjutkan menonton","Filter kategori","Cari","Kecepatan pemutaran","Normal","Kecepatan normal","Gambar dalam Gambar","Timer tidur","Semua daftar putar","Tidak ada hasil","%d mnt","Bahasa antarmuka"],"vi":["Trực tiếp","Phim","Phim bộ","Tất cả","Yêu thích","Xem tiếp","Lọc danh mục","Tìm kiếm","Tốc độ phát","Bình thường","Tốc độ bình thường","Hình trong hình","Hẹn giờ ngủ","Tất cả danh sách phát","Không tìm thấy gì","%d ph","Ngôn ngữ giao diện"],"th":["สด","ภาพยนตร์","ซีรีส์","ทั้งหมด","รายการโปรด","ดูต่อ","กรองหมวดหมู่","ค้นหา","ความเร็วในการเล่น","ปกติ","ความเร็วปกติ","ภาพซ้อนภาพ","ตั้งเวลาปิด","เพลย์ลิสต์ทั้งหมด","ไม่พบรายการ","%d น.","ภาษาของอินเทอร์เฟซ"],"zh-Hans":["直播","电影","剧集","全部","收藏","继续观看","筛选分类","搜索","播放速度","正常","正常速度","画中画","睡眠定时","所有播放列表","没有找到结果","%d 分","界面语言"],"zh-Hant":["直播","電影","影集","全部","我的最愛","繼續觀看","篩選類別","搜尋","播放速度","正常","正常速度","子母畫面","睡眠計時器","所有播放清單","找不到任何內容","%d 分","介面語言"],"ja":["ライブ","映画","シリーズ","すべて","お気に入り","続きを見る","カテゴリを絞り込む","検索","再生速度","標準","標準速度","ピクチャインピクチャ","スリープタイマー","すべてのプレイリスト","見つかりませんでした","%d分","インターフェイスの言語"],"ko":["라이브","영화","시리즈","전체","즐겨찾기","이어보기","카테고리 필터","검색","재생 속도","보통","보통 속도","화면 속 화면","잠자기 타이머","모든 재생목록","결과 없음","%d분","인터페이스 언어"]};
  var LANGS = [["he","עברית"],["en","English"],["ar","العربية"],["es","Español"],["fr","Français"],["de","Deutsch"],["pt","Português"],["it","Italiano"],["ru","Русский"],["uk","Українська"],["pl","Polski"],["ro","Română"],["bg","Български"],["nl","Nederlands"],["sv","Svenska"],["cs","Čeština"],["hu","Magyar"],["el","Ελληνικά"],["sq","Shqip"],["tr","Türkçe"],["fa","فارسی"],["ur","اردو"],["hi","हिन्दी"],["bn","বাংলা"],["id","Bahasa Indonesia"],["vi","Tiếng Việt"],["th","ไทย"],["zh-Hans","简体中文"],["zh-Hant","繁體中文"],["ja","日本語"],["ko","한국어"]];
  var RTL = { he: 1, ar: 1, fa: 1, ur: 1 };
  var SCENES = ['search', 'player', 'pip', 'playlists', 'languages'];
  var EASE = 'cubic-bezier(.22,1,.36,1)';
  // Strings the app does not translate in this mock (page language only: en, he; anything else shows English).
  var X = {
    en: { label: 'Interactive preview of the IPTVMac app', items: 'items', res: 'results', one: 'result', off: 'Off', play: 'Play', pause: 'Pause', back: 'Back', clear: 'Clear',
      skipb: 'Skip back 10 seconds', skipf: 'Skip forward 10 seconds', seek: 'Playback position', pipw: 'Picture in Picture window', close: 'Close', ret: 'Back to app', det: 'Details',
      plot: 'Plot', cast: 'Cast', dir: 'Director', pls: 'Playlists', src: ['Xtream Codes', 'M3U', 'Xtream Codes'], lang: 'Interface language', sub: 'Subtitles', aud: 'Audio', full: 'Full screen' },
    he: { label: 'תצוגה אינטראקטיבית של האפליקציה IPTVMac', items: 'פריטים', res: 'תוצאות', one: 'תוצאה', off: 'כבוי', play: 'נגן', pause: 'השהה', back: 'חזרה', clear: 'נקה',
      skipb: 'חזרה 10 שניות', skipf: 'דילוג 10 שניות קדימה', seek: 'מיקום ההפעלה', pipw: 'חלון תמונה בתוך תמונה', close: 'סגור', ret: 'חזרה לאפליקציה', det: 'פרטים',
      plot: 'תקציר', cast: 'שחקנים', dir: 'במאי', pls: 'רשימות', src: ['Xtream Codes', 'M3U', 'Xtream Codes'], lang: 'שפת הממשק', sub: 'כתוביות', aud: 'שמע', full: 'מסך מלא' }
  };
  var PL = [['Home', 'בית'], ['Travel', 'טיולים'], ['Weekend', 'סופ״ש']];
  var CAT = {
    l: [['News', 'חדשות'], ['Documentary', 'תיעודי'], ['Kids', 'ילדים'], ['Music', 'מוזיקה']],
    m: [['Drama', 'דרמה'], ['Sci-Fi', 'מד״ב'], ['Animation', 'אנימציה'], ['Comedy', 'קומדיה']],
    s: [['Series', 'סדרות']]
  };
  // type | English title | Hebrew title | category | year   (every title is invented)
  var RAW = [
    'l|City News 24|חדשות העיר 24|0', 'l|World Report|דוח עולמי|0', 'l|Nature One|ערוץ הטבע|1', 'l|Planet Docs|פלנט דוקו|1', 'l|Ocean Life|חיי הים|1',
    'l|Kids Cartoons|קריקטורות לילדים|2', 'l|Toon Time|זמן טון|2', 'l|Music Hits|להיטי השנה|3', 'l|Jazz Lounge|לאונג׳ ג׳אז|3', 'l|Retro Radio TV|רטרו טי־וי|3', 'l|Starline TV|כוכב טי־וי|0',
    'm|The Last Lighthouse|המגדלור האחרון|0|2024', 'm|Paper Moons|ירחי נייר|0|2023', 'm|Quiet Harbor|נמל שקט|0|2022', 'm|Winter Letters|מכתבי חורף|0|2021',
    'm|Nebula Run|ריצת הערפילית|1|2025', 'm|Orbit Zero|מסלול אפס|1|2024', 'm|Signal from Kepler|אות מקפלר|1|2023', 'm|The Mirror Planet|כוכב המראה|1|2022',
    'm|Dragon Valley|עמק הדרקונים|2|2024', 'm|Little Cloud|ענן קטן|2|2023', 'm|Fox & Ember|שועל וגחלת|2|2022', 'm|Wrong Wedding|חתונה לא נכונה|3|2024',
    'm|Office Chaos|בלגן במשרד|3|2023', 'm|The Sea Cook|הטבח של הים|3|2021', 'm|Lucky Streak|רצף מזל|3|2022', 'm|Desert Wind|רוח מדבר|0|2020',
    'm|Seaside Story|סיפור על חוף הים|0|2019', 'm|Star Harbor|נמל הכוכבים|1|2025', 'm|Moon Garden|גן הירח|2|2021', 'm|Starlight Express|אקספרס אור כוכבים|2|2023',
    'm|Stardust Diner|מסעדת אבק כוכבים|3|2020', 'm|The Salt Road|דרך המלח|0|2022', 'm|Copper Skies|שמי נחושת|1|2024', 'm|A Quiet Season|עונה שקטה|0|2021',
    'm|Glass Orchard|פרדס הזכוכית|0|2023', 'm|Midnight Ferry|מעבורת חצות|1|2022', 'm|The Paper Kite|עפיפון הנייר|2|2019', 'm|Last Train to Aven|הרכבת האחרונה לאבן|0|2025',
    'm|Blue Hour|השעה הכחולה|0|2022', 'm|Silver Tide|גאות כסופה|1|2023',
    's|Harbor Lights|אורות הנמל|0', 's|Kepler Station|תחנת קפלר|0', 's|Little Detectives|בלשים קטנים|0', 's|The Bakery|המאפייה|0', 's|Night Shift|משמרת לילה|0',
    's|Cloud Meadow Kids|ילדי שדה העננים|0', 's|Deep Blue|כחול עמוק|0', 's|City Doctors|רופאי העיר|0', 's|Sea of Secrets|ים של סודות|0', 's|Pixel Heroes|גיבורי פיקסל|0',
    's|Old Roots|שורשים ישנים|0', 's|Old Town|העיר העתיקה|0', 's|Starfall Academy|אקדמיית הכוכב הנופל|0', 's|The Long Winter|החורף הארוך|0', 's|Copper Street|רחוב הנחושת|0',
    's|Rooftop Chefs|שפים על הגג|0', 's|Northern Line|הקו הצפוני|0', 's|Glass Harbor|נמל הזכוכית|0', 's|Tin Soldiers Club|מועדון חיילי הפח|0', 's|Morning Crew|צוות הבוקר|0'
  ];
  var HUES = [238, 282, 322, 6, 154, 198, 262, 340, 214, 300, 176, 350];
  var QRY = { en: 'star', he: 'כוכב' };
  var ITEMS = RAW.map(function (r, i) {
    var a = r.split('|');
    return { i: i, t: a[0], en: a[1], he: a[2], c: +a[3], y: a[4], h: HUES[(i * 7) % 12] };
  });
  // Playlists scene: 12 posters, interleaved Home, Travel, Weekend
  var PLITEMS = [11, 42, 29, 15, 47, 20, 24, 45, 30, 13, 52, 22].map(function (i, k) { var it = Object.create(ITEMS[i]); it.pl = k % 3; return it; });
  var SPEEDS = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4];
  var DUR = 6480, SLEEPS = [15, 30, 45, 60, 90, 120];

  function clamp(x, a, b) { return x < a ? a : x > b ? b : x; }
  function mix(a, b, t) { return a + (b - a) * t; }
  function sg(p, a, b) { return p <= a ? 0 : p >= b ? 1 : (p - a) / (b - a); }
  function ez(x) { return x < .5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2; }
  function eo(x) { return 1 - Math.pow(1 - x, 3); }
  function eq(x) { return 1 - Math.pow(1 - x, 4); }
  function pad(n) { return n < 10 ? '0' + n : '' + n; }
  function tcode(s) { s = Math.max(0, Math.floor(s)); return ((s / 3600) | 0) + ':' + pad((s % 3600 / 60) | 0) + ':' + pad(s % 60); }
  function tshort(s) { s = Math.max(0, Math.floor(s)); return s >= 3600 ? tcode(s) : ((s / 60) | 0) + ':' + pad(s % 60); }
  function fs(v) { return (+v.toFixed(2)) + '×'; }
  function esc(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;'); }
  function nrm(s) { return s.normalize('NFD').replace(/[̀-ְͯ-ׇ]/g, '').toLowerCase(); }
  function nl(l) { return T[l] ? l : (l && T[String(l).split('-')[0]]) ? String(l).split('-')[0] : 'en'; }
  function E(t, c, h) { var e = D.createElement(t); if (c) e.className = c; if (h != null) e.innerHTML = h; return e; }
  function trunc(v, d) { return Math.round(v * d) / d; }
  // Position of el inside win in CSS pixels (offset chain: unaffected by transforms on ancestors).
  function off(el, win) { var x = 0, y = 0; while (el && el !== win) { x += el.offsetLeft; y += el.offsetTop; el = el.offsetParent; } return [x, y]; }
  // Catmull-Rom through points, u in 0..1
  function spl(P, u) {
    var n = P.length - 1, f = clamp(u, 0, 1) * n, i = Math.min(n - 1, f | 0), t = f - i, a = P[Math.max(i - 1, 0)], b = P[i], c = P[i + 1], d = P[Math.min(i + 2, n)], o = [];
    for (var k = 0; k < 2; k++) o[k] = .5 * (2 * b[k] + (-a[k] + c[k]) * t + (2 * a[k] - 5 * b[k] + 4 * c[k] - d[k]) * t * t + (-a[k] + 3 * b[k] - 3 * c[k] + d[k]) * t * t * t);
    return o;
  }

  // Drawn icons, 24px grid. Stroked unless the svg gets class f (filled).
  var IC = {
    side: '<rect x="3" y="5" width="18" height="14" rx="3"/><path d="M9.5 5v14"/>',
    search: '<circle cx="10.5" cy="10.5" r="5.8"/><path d="m15 15 4.6 4.6"/>',
    dl: '<circle cx="12" cy="12" r="8.6"/><path d="M12 7.8v7.6m-3.4-3.4 3.4 3.4 3.4-3.4"/>',
    sync: '<path d="M19.2 12a7.2 7.2 0 1 1-2.2-5.2"/><path d="M19.4 4.6v4.2h-4.2"/>',
    grid: '<rect x="4" y="4" width="6.6" height="6.6" rx="1.7"/><rect x="13.4" y="4" width="6.6" height="6.6" rx="1.7"/><rect x="4" y="13.4" width="6.6" height="6.6" rx="1.7"/><rect x="13.4" y="13.4" width="6.6" height="6.6" rx="1.7"/>',
    star: '<path d="m12 3.7 2.5 5.2 5.7.8-4.1 4 1 5.7-5.1-2.7-5.1 2.7 1-5.7-4.1-4 5.7-.8z"/>',
    clock: '<circle cx="12" cy="12" r="8.6"/><path d="M12 7.3V12l3.2 2"/>',
    back: '<path d="m14.6 5.6-6.4 6.4 6.4 6.4"/>',
    play: '<path d="M8 5.7v12.6a.8.8 0 0 0 1.2.7l10-6.3a.8.8 0 0 0 0-1.4l-10-6.3A.8.8 0 0 0 8 5.7z"/>',
    pause: '<rect x="6.4" y="4.8" width="3.8" height="14.4" rx="1.2"/><rect x="13.8" y="4.8" width="3.8" height="14.4" rx="1.2"/>',
    fwd: '<path d="M15.4 6.3a7.4 7.4 0 1 1-4.7-.9"/><path d="m9.7 3 3 2.4-3 2.5"/><text x="12" y="16" text-anchor="middle" font-size="7.6" font-weight="700" fill="currentColor" stroke="none">10</text>',
    bwd: '<path d="M8.6 6.3a7.4 7.4 0 1 0 4.7-.9"/><path d="m14.3 3-3 2.4 3 2.5"/><text x="12" y="16" text-anchor="middle" font-size="7.6" font-weight="700" fill="currentColor" stroke="none">10</text>',
    cc: '<path d="M6 5.5h12a2.6 2.6 0 0 1 2.6 2.6v6.6a2.6 2.6 0 0 1-2.6 2.6h-5.2L8.4 20.6v-3.3H6a2.6 2.6 0 0 1-2.6-2.6V8.1A2.6 2.6 0 0 1 6 5.5z"/><path d="M7.4 10.4h3m2.8 0h3.4M7.4 13.4h4.2m2.2 0h2.8"/>',
    aud: '<path d="M4 9.8h3l4.3-3.5v11.4L7 14.2H4z"/><path d="M14.6 9.3a3.6 3.6 0 0 1 0 5.4M17.2 6.7a7.2 7.2 0 0 1 0 10.6"/>',
    moon: '<path d="M18.8 14.6A7.2 7.2 0 0 1 9.4 5.2a7.2 7.2 0 1 0 9.4 9.4z"/><path d="M14.6 3.6h3.2l-3.2 3.6h3.2"/>',
    pip: '<rect x="3" y="5" width="18" height="14" rx="2.8"/><rect x="11.4" y="11.4" width="7" height="5" rx="1.3" fill="currentColor"/>',
    full: '<path d="M14 4h6v6m-10 10H4v-6M20 4l-6.6 6.6M4 20l6.6-6.6"/>',
    xc: '<circle cx="12" cy="12" r="10" fill="currentColor" stroke="none"/><path d="m8.6 8.6 6.8 6.8m0-6.8-6.8 6.8" stroke="var(--cut,#111)" stroke-width="2"/>',
    ck: '<path d="m5.6 12.6 4.1 4.1 8.7-9.3" stroke-width="2.4"/>',
    info: '<path d="M12 10.9v5.6M12 7.6v.2" stroke-width="2.6"/>',
    stack: '<path d="m12 4 8.4 4.2L12 12.4 3.6 8.2z"/><path d="m3.6 12 8.4 4.2 8.4-4.2M3.6 15.8 12 20l8.4-4.2"/>',
    slow: '<path d="M4.2 16.6a7.4 6.6 0 0 1 14.8 0z" fill="currentColor" stroke="none"/><circle cx="20.6" cy="13.6" r="2" fill="currentColor" stroke="none"/><path d="M7.6 16.6v2.6m8 -2.6v2.6M4.2 15.6 2.8 16.6" stroke-width="2"/>',
    fast: '<ellipse cx="10.6" cy="15" rx="7" ry="4.2" fill="currentColor" stroke="none"/><circle cx="17.8" cy="11.4" r="2.8" fill="currentColor" stroke="none"/><path d="m17 9.4-1.6-5.6m3.4 5.4.9-5.4" stroke-width="2.1"/><circle cx="3.9" cy="13.9" r="1.6" fill="currentColor" stroke="none"/>',
    plus: '<path d="M12 5v14M5 12h14"/>'
  };
  function I(n, c) { return '<svg class="i' + (c ? ' ' + c : '') + '" viewBox="0 0 24 24" aria-hidden="true" focusable="false">' + IC[n] + '</svg>'; }

  // The generated "film": a lighthouse at dusk that turns into night. tau 0..1 is the film's own time.
  var SKY = [[222, 45, 20, 285, 50, 38, 378, 85, 62], [232, 50, 16, 262, 45, 30, 345, 55, 50], [228, 55, 8, 232, 50, 16, 250, 55, 28]];
  var FRAME = '<i class="v-sky"></i><i class="v-sun"></i><i class="v-moon"></i><i class="v-cl"></i><i class="v-sea"></i><i class="v-beam"></i><i class="v-rock"></i><i class="v-twr"></i><i class="v-str"></i><i class="v-vig"></i>';
  function hsl(h, s, l) { return 'hsl(' + trunc(h, 10) + ' ' + trunc(s, 10) + '% ' + trunc(l, 10) + '%)'; }
  function paint(el, tau, ba, cx, sk, so) {
    var a = tau < .5 ? SKY[0] : SKY[1], b = tau < .5 ? SKY[1] : SKY[2], t = ez(tau < .5 ? tau * 2 : (tau - .5) * 2), c = [], i, k_ = el._c || (el._c = {}), s = { setProperty: function (k, v) { if (k_[k] !== v) { k_[k] = v; el.style.setProperty(k, v); } } };
    for (i = 0; i < 9; i++) c[i] = mix(a[i], b[i], t);
    s.setProperty('--c1', hsl(c[0], c[1], c[2])); s.setProperty('--c2', hsl(c[3], c[4], c[5])); s.setProperty('--c3', hsl(c[6], c[7], c[8]));
    s.setProperty('--sea', hsl(c[3] - 6, c[4] * .8, c[5] * .55)); s.setProperty('--sea2', hsl(c[6] - 20, c[7] * .5, c[8] * .45));
    s.setProperty('--sx', trunc(mix(74, 58, tau), 10) + '%'); s.setProperty('--sy', trunc(mix(60, 98, eo(tau)), 10) + '%');
    s.setProperty('--so', trunc(1 - sg(tau, .25, .62), 100)); s.setProperty('--mo', trunc(sg(tau, .5, .9), 100));
    s.setProperty('--bo', trunc(mix(.18, .85, sg(tau, .05, .8)), 100));
    if (ba != null) { s.setProperty('--ba', trunc(ba, 10) + 'deg'); s.setProperty('--cx', trunc(cx, 100)); s.setProperty('--sk', trunc(sk, 100)); s.setProperty('--sp', trunc(so, 100)); }
  }

  function mount(root, o) {
    o = o || {};
    if (root.__iptvdemo) root.__iptvdemo.destroy();
    var mq = W.matchMedia ? W.matchMedia('(prefers-reduced-motion: reduce)') : null;
    var S = { sc: 'search', p: { search: 0, player: 0, pip: 0, playlists: 0, languages: 0 }, base: nl(o.lang), lang: nl(o.lang), rm: o.reducedMotion == null ? !!(mq && mq.matches) : !!o.reducedMotion,
      vis: true, amb: 0, ph: 0, paused: false, pt: 0, dead: false };
    var NF = {}, U = {}, M = { dirty: true, t: {} }, F = {}, R = {}, H = {}, tw = null, raf = 0, last = 0, qf = 0, drag = null, fx = 0, offs = [], hid = [], swT = 0;
    var win = E('div', 'd-win');
    var nm = function () { return S.base === 'he' ? 'he' : 'en'; };
    var xs = function (k) { return X[nm()][k]; };
    var tr = function (i) { return T[S.lang][i]; };

    // ---------- DOM
    function pc(it, cls) {
      return '<div class="d-pc ' + (cls || '') + '" style="--h:' + it.h + '"><div class="d-pz"><b class="d-pt"></b><small class="d-pg"></small><i class="d-bd"></i><span class="d-pi">' + I('info') + '</span></div><span class="d-cap"></span></div>';
    }
    var lr = function (it) { return '<div class="d-lr" style="--h:' + it.h + '"><span class="d-lg"></span><span class="d-ln"></span><i class="d-bd"></i>' + I('star') + '</div>'; };
    var byT = function (t) { return ITEMS.filter(function (x) { return x.t === t; }); };
    var spRows = SPEEDS.map(function (v) { return '<button type="button" class="d-pr" data-v="' + v + '" tabindex="-1">' + I('ck') + '<span>' + fs(v) + '</span>' + (v === 1 ? '<em data-t="sn"></em>' : '') + '</button>'; }).join('');
    var ticks = SPEEDS.map(function (v) { return '<i class="d-tk" style="left:' + trunc((v - .25) / 3.75 * 100, 100) + '%"></i>'; }).join('');
    var slm = '<button type="button" role="menuitem" class="d-mi" data-m="0"><span data-r="off"></span></button>' + SLEEPS.map(function (m) { return '<button type="button" role="menuitem" class="d-mi" data-m="' + m + '"><span data-n="' + m + '"></span></button>'; }).join('');
    var plm = '<button type="button" role="menuitemradio" class="d-mi" data-pl="all">' + I('ck') + I('stack') + '<span data-t="pa"></span></button>' + PL.map(function (n, i) { return '<button type="button" role="menuitemradio" class="d-mi" data-pl="' + i + '">' + I('ck') + '<span data-pn="' + i + '"></span></button>'; }).join('');
    win.innerHTML =
      '<i class="d-lights" aria-hidden="true"><b></b><b></b><b></b></i>' +
      '<aside class="d-side" aria-hidden="true"><div class="d-sbt"><span class="d-ib">' + I('side') + '</span></div><div class="d-fil" data-t="cx"></div>' +
      '<div class="d-sl"><div class="d-row on">' + I('grid') + '<span data-t="ca"></span></div><div class="d-row">' + I('star') + '<span data-t="cf"></span></div><div class="d-row">' + I('clock') + '<span data-t="cc"></span></div>' +
      '<div class="d-cw"><div class="d-cats" data-r="cats"></div><div class="d-cats" data-r="cats2"></div></div></div></aside>' +
      '<section class="d-mn"><header class="d-bar"><div class="d-bl"><span class="d-ib d-bk" aria-hidden="true">' + I('back', 'mir') + '</span><b class="d-ttl" aria-hidden="true">IPTVMac</b></div>' +
      '<div class="d-seg" role="group" data-r="seg"><button type="button" data-k="l"><span data-t="tl"></span></button><button type="button" data-k="m"><span data-t="tm"></span></button><button type="button" data-k="s"><span data-t="ts"></span></button></div>' +
      '<div class="d-br"><button type="button" class="d-chip" data-r="chip" aria-haspopup="menu" aria-expanded="false">' + I('stack') + '<span data-r="chipn"></span></button>' +
      '<span class="d-ib d-ico" aria-hidden="true">' + I('dl') + '</span><span class="d-ib d-ico" aria-hidden="true">' + I('sync') + '</span>' +
      '<label class="d-sf" data-r="sf">' + I('search') + '<input class="d-in" data-r="inp" type="text" spellcheck="false" autocomplete="off" autocapitalize="off" enterkeyhint="search"><span class="d-sm" data-r="sim"></span>' +
      '<button type="button" class="d-x" data-r="clr" tabindex="-1">' + I('xc') + '</button></label></div></header>' +
      '<div class="d-stage" data-r="stage">' +
      // library: live rows, movie posters, series posters
      '<div class="d-lay d-lib" data-r="lib" aria-hidden="true"><div class="d-scr">' +
      '<section class="d-sec" data-k="l"><h3 class="d-sh" data-t="tl"></h3><div class="d-rows">' + byT('l').map(lr).join('') + '</div></section>' +
      '<section class="d-sec" data-k="m"><h3 class="d-sh" data-t="tm"></h3><div class="d-grid">' + byT('m').map(function (x) { return pc(x); }).join('') + '</div></section>' +
      '<section class="d-sec" data-k="s"><h3 class="d-sh" data-t="ts"></h3><div class="d-grid">' + byT('s').map(function (x) { return pc(x); }).join('') + '</div></section>' +
      '<div class="d-empty" data-r="empty">' + I('search') + '<b data-t="er"></b><span data-r="emq"></span></div></div>' +
      '<div class="d-cnt" data-r="cnt"><i class="d-dot"></i><b data-r="cn">0</b><span data-r="ci"></span><span data-r="rs"></span></div></div>' +
      // playlists
      '<div class="d-lay d-pl" data-r="pl" aria-hidden="true"><div class="d-plb">' + PL.map(function (n, i) { return '<div class="d-plp" data-i="' + i + '"><b data-pn="' + i + '"></b><small data-src="' + i + '"></small></div>'; }).join('') + '</div>' +
      '<div class="d-plg">' + PLITEMS.map(function (x) { return pc(x, 'd-pp'); }).join('') + '</div></div>' +
      // language wall
      '<div class="d-lay d-wall" data-r="wall"><div class="d-wh" data-t="il"></div><div class="d-lw" role="radiogroup" data-r="lw">' +
      LANGS.map(function (l) { return '<button type="button" class="d-lt" role="radio" aria-checked="false" tabindex="-1" data-l="' + l[0] + '" lang="' + l[0] + '" dir="' + (RTL[l[0]] ? 'rtl' : 'ltr') + '"><b>' + l[1] + '</b><small>' + l[0] + '</small></button>'; }).join('') + '</div>' +
      '<div class="d-pvw" aria-hidden="true"><span>' + I('slow') + '<i data-t="sd"></i></span><span>' + I('pip') + '<i data-t="pip"></i></span><span>' + I('moon') + '<i data-t="sl"></i></span><span>' + I('stack') + '<i data-t="pa"></i></span></div></div>' +
      // player
      '<div class="d-lay d-vid" data-r="vid"><div class="d-vs"><div class="vf" data-r="vf">' + FRAME + '</div></div><div class="d-vc" data-r="vc">' +
      '<div class="d-vt"><span class="d-ib">' + I('xc') + '</span><b data-r="vti"></b><span class="d-ib d-fv">' + I('star') + '</span></div>' +
      '<div class="d-ctl" data-r="ctl"><button type="button" class="d-ib" data-r="pp">' + I('pause', 'f') + '</button><button type="button" class="d-ib d-sk10" data-r="bw">' + I('bwd') + '</button><button type="button" class="d-ib d-sk10" data-r="fw">' + I('fwd') + '</button>' +
      '<div class="d-sk" data-r="sk" role="slider" tabindex="0" aria-valuemin="0" aria-valuemax="' + DUR + '"><i class="d-tr"></i><i class="d-hf" data-r="hf"></i><i class="d-pf" data-r="pf"></i><i class="d-th" data-r="th"></i><i class="d-mk" data-r="mk"></i></div>' +
      '<span class="d-tm" data-r="tm"></span><button type="button" class="d-spd" data-r="spd" aria-haspopup="dialog" aria-expanded="false"></button>' +
      '<span class="d-ib d-opt" aria-hidden="true">' + I('cc') + '</span><span class="d-ib d-opt" aria-hidden="true">' + I('aud') + '</span>' +
      '<button type="button" class="d-ib d-moon" data-r="moon" aria-haspopup="menu" aria-expanded="false">' + I('moon') + '</button><span class="d-zl" data-r="zl"></span>' +
      '<button type="button" class="d-ib" data-r="pipb">' + I('pip') + '</button><span class="d-ib d-opt" aria-hidden="true">' + I('full') + '</span></div></div>' +
      '<div class="d-bub" data-r="bub" aria-hidden="true"><div class="vf" data-r="bf">' + FRAME + '</div><b data-r="bt"></b></div>' +
      '<div class="d-pop off" data-r="pop" role="dialog"><h4 data-t="sd"></h4><div class="d-pv"><div class="d-pls" data-r="pls">' + spRows + '</div></div><hr>' +
      '<div class="d-sr"><span class="d-ic">' + I('slow') + '</span><div class="d-rg" data-r="rg" role="slider" tabindex="0" aria-valuemin="0.25" aria-valuemax="4"><i class="d-rt"></i>' + ticks + '<i class="d-rf" data-r="rf"></i><i class="d-rk" data-r="rk"></i></div><span class="d-ic">' + I('fast') + '</span></div>' +
      '<div class="d-sb"><button type="button" class="d-btn" data-r="rst" data-t="sr"></button><b data-r="rb"></b></div></div>' +
      '<div class="d-menu d-slm off" data-r="slm" role="menu">' + slm + '</div></div>' +
      '<div class="d-menu d-plm off" data-r="plm" role="menu">' + plm + '</div>' +
      // picture in picture window
      '<div class="d-pipw off" data-r="pip" role="group" tabindex="0"><div class="vf" data-r="pvf">' + FRAME + '</div><div class="d-pch"><button type="button" class="d-ib" data-r="pcl">' + I('xc') + '</button><button type="button" class="d-ib" data-r="pre">' + I('full') + '</button><button type="button" class="d-ib d-ppb" data-r="ppp">' + I('pause', 'f') + '</button></div></div>' +
      '</div></section><div class="d-sheet off" data-r="sheet"><div class="d-dlg" role="dialog" aria-modal="false" data-r="sdlg"><div class="d-sposter" data-r="spz"></div><div class="d-sbody"><div class="d-shd"><h2 data-r="sti"></h2><button type="button" class="d-btn" data-r="scl"></button></div><div class="d-meta" data-r="smeta"></div>' +
      '<div class="d-act"><button type="button" class="d-play" data-r="splay">' + I('play', 'f') + '<span></span></button><span class="d-sq">' + I('star') + '</span><span class="d-sq">' + I('dl') + '</span></div><div class="d-info" data-r="sinfo"></div></div></div></div><span class="d-cur" data-r="cur" aria-hidden="true"><svg viewBox="0 0 20 24"><path d="M3 2.4 3.2 17l3.8-3.5 2.6 5.8 2.7-1.2-2.6-5.7 5.2-.1z" fill="#fff" stroke="#000" stroke-width="1.3" stroke-linejoin="round"/></svg><i></i></span>';
    // keep whatever the page put inside the root (static fallback) out of sight while the demo runs
    [].slice.call(root.children).forEach(function (n) { hid.push([n, n.hidden]); n.hidden = true; });
    root.appendChild(win);
    root.setAttribute('data-iptvdemo', '');
    var rold = [root.getAttribute('role'), root.getAttribute('aria-label')];
    if (!root.getAttribute('role')) root.setAttribute('role', 'group');
    if (!root.getAttribute('aria-label')) root.setAttribute('aria-label', xs('label'));
    [].forEach.call(win.querySelectorAll('[data-r]'), function (e) { R[e.getAttribute('data-r')] = e; });
    var Q = function (s, r) { return (r || win).querySelector(s); }, QA = function (s, r) { return [].slice.call((r || win).querySelectorAll(s)); };
    var cells = QA('.d-lib .d-pc'), rows = QA('.d-lib .d-lr'), secs = QA('.d-sec'), pcells = QA('.d-pl .d-pc');
    ITEMS.filter(function (x) { return x.t !== 'l'; }).forEach(function (x, i) { x.el = cells[i]; });
    byT('l').forEach(function (x, i) { x.el = rows[i]; });
    ITEMS.forEach(function (x) { x.el._it = x; });
    PLITEMS.forEach(function (x, i) { x.el = pcells[i]; x.bd = x.el.querySelector('.d-bd'); });
    var plps = QA('.d-plp'), segB = QA('button', R.seg), tiles = QA('.d-lt'), slmI = QA('.d-mi', R.slm), plmI = QA('.d-mi', R.plm), prs = QA('.d-pr', R.pls);

    function on(el, ev, fn, opt) { el.addEventListener(ev, fn, opt); offs.push(function () { el.removeEventListener(ev, fn, opt); }); }
    function usr(sc) { return U[sc] || (U[sc] = { _p: S.p[sc] }); }
    function req() { if (!qf && !S.dead) { qf = requestAnimationFrame(function () { qf = 0; render(); }); } }
    // cached style writes
    function st(el, k, v) { var c = el._c || (el._c = {}); if (c[k] !== v) { c[k] = v; el.style[k] = v; } }
    function sv(el, k, v) { var c = el._c || (el._c = {}); if (c[k] !== v) { c[k] = v; el.style.setProperty(k, v); } }
    function tx(el, v) { if (el._tx !== v) { el._tx = v; el.textContent = v; } }
    function cls(el, c, on_) { if (el._k === undefined) el._k = {}; if (el._k[c] !== !!on_) { el._k[c] = !!on_; el.classList.toggle(c, !!on_); } }
    function at(el, k, v) { var c = el._a || (el._a = {}); if (c[k] !== v) { c[k] = v; el.setAttribute(k, v); } }

    // ---------- language + names
    function setNames() {
      var h = nm() === 'he';
      ITEMS.concat(PLITEMS).forEach(function (x) {
        if (!x.el) return; var n = h ? x.he : x.en, tl = x.t === 'm' ? n + ' (' + x.y + ')' : n;
        x.name = tl;
        if (x.t === 'l') { x.el.querySelector('.d-ln').textContent = n; x.el.querySelector('.d-lg').textContent = ini(n); }
        else { x.el.querySelector('.d-pt').textContent = tl; x.el.querySelector('.d-cap').textContent = tl; x.el.querySelector('.d-pg').textContent = CAT[x.t][x.c][h ? 1 : 0]; }
        x.q = nrm(tl);
      });
      F.key = null; M.cats = null;
      QA('[data-pn]').forEach(function (e) { e.textContent = PL[+e.getAttribute('data-pn')][h ? 1 : 0]; });
      QA('[data-src]').forEach(function (e) { e.textContent = xs('src')[+e.getAttribute('data-src')]; });
      R.vti.textContent = ITEMS[11].name; 
      R.pcl.setAttribute('aria-label', xs('close')); R.pre.setAttribute('aria-label', xs('ret')); R.pip.setAttribute('aria-label', xs('pipw'));
      R.bw.setAttribute('aria-label', xs('skipb')); R.fw.setAttribute('aria-label', xs('skipf')); R.sk.setAttribute('aria-label', xs('seek'));
      R.clr.setAttribute('aria-label', xs('clear')); R.inp.setAttribute('aria-label', tr(7)); 
      R.off.textContent = xs('off'); R.pop.setAttribute('aria-label', tr(8)); R.rg.setAttribute('aria-label', tr(8));
      QA('.d-bk', win).forEach(function (e) { e.setAttribute('aria-label', xs('back')); });
    }
    function ini(n) { var w = n.replace(/[^\p{L}\p{N} ]/gu, '').split(' ').filter(Boolean); return (w.length > 1 ? w[0][0] + w[1][0] : n.slice(0, 2)).toUpperCase(); }
    function applyLang(anim) {
      var l = S.lang, d = T[l], rt = RTL[l] ? 'rtl' : 'ltr', changed = win._l !== l;
      if (!changed) return;
      var flip = win.dir !== rt;
      win._l = l; win.dir = rt; win.lang = l;
      QA('[data-t]').forEach(function (e) {
        var v = d[K.indexOf(e.getAttribute('data-t'))];
        if (e._tx !== v) { e._tx = v; e.textContent = v; if (anim && !S.rm && e.animate && !e.closest('[hidden]')) e.animate([{ opacity: .15, transform: 'translateY(.22em)' }, { opacity: 1, transform: 'none' }], { duration: 340, easing: EASE }); }
      });
      R.moon.setAttribute('aria-label', d[12]); R.pipb.setAttribute('aria-label', d[11]); R.chip.setAttribute('aria-label', d[13]); R.inp.setAttribute('placeholder', d[7]); R.inp.setAttribute('aria-label', d[7]); R.pop.setAttribute('aria-label', d[8]); R.rg.setAttribute('aria-label', d[8]);
      QA('[data-n]').forEach(function (e) { e.textContent = d[15].replace('%d', e.getAttribute('data-n')); }); R.lw.setAttribute('aria-label', d[16]);
      tiles.forEach(function (t) { var on_ = t.getAttribute('data-l') === l; t.setAttribute('aria-checked', on_); cls(t, 'on', on_); });
      if (flip) { M.dirty = true; if (anim && !S.rm && win.animate) { var a = [{ opacity: .35, transform: 'scaleX(.985)' }, { opacity: 1, transform: 'none' }], b = { duration: 460, easing: EASE }; Q('.d-side').animate(a, b); Q('.d-mn').animate(a, b); } }
      M.cats = null; M.dirty = true;
    }

    // ---------- measuring (offsets only: no transforms involved, no per-frame layout reads)
    function ctr(el, fx_, fy_) { var o_ = off(el, win); return [o_[0] + el.offsetWidth * (fx_ == null ? .5 : fx_), o_[1] + el.offsetHeight * (fy_ == null ? .5 : fy_)]; }
    function measure() {
      if (!win.offsetWidth) return;
      M.dirty = false;
      var t = M.t, so = off(R.stage, win), sw = R.stage.offsetWidth, sh = R.stage.offsetHeight;
      M.so = so; M.sw = sw; M.sh = sh; M.w = win.offsetWidth; M.h = win.offsetHeight; M.em = parseFloat(getComputedStyle(win).fontSize) || 16;
      var rel = function (e) { var q = off(e, win); return [q[0] - so[0], q[1] - so[1]]; };
      var sk = rel(R.sk); t.sk = [sk[0], sk[1], R.sk.offsetWidth, R.sk.offsetHeight];
      var ct = rel(R.ctl); t.ctl = [ct[0], ct[1], R.ctl.offsetWidth, R.ctl.offsetHeight];
      t.spd = rel(R.spd); t.spdw = R.spd.offsetWidth; t.bubh = R.bub.offsetHeight; t.bubw = R.bub.offsetWidth;
      var pw = R.pop.offsetWidth, ph = R.pop.offsetHeight, px = clamp(t.spd[0] + t.spdw / 2 - pw / 2, 8, sw - pw - 8);
      R.pop.style.left = px + 'px'; R.pop.style.top = (ct[1] - ph - 10) + 'px'; R.pop.style.setProperty('--ax', (t.spd[0] + t.spdw / 2 - px) + 'px');
      var rg = off(R.rg, win); t.rgw = R.rg.offsetWidth; t.rgh = R.rg.offsetHeight; t.rgx = rg;
      var mo = rel(R.moon), mw = R.slm.offsetWidth, mh = R.slm.offsetHeight, mx = clamp(mo[0] + R.moon.offsetWidth / 2 - mw / 2, 8, sw - mw - 8);
      R.slm.style.left = mx + 'px'; R.slm.style.top = (ct[1] - mh - 10) + 'px';
      var ch = off(R.chip, win), cw_ = R.plm.offsetWidth, cx_ = clamp(ch[0], 6, M.w - cw_ - 6);
      R.plm.style.left = (cx_ - so[0]) + 'px'; R.plm.style.top = (ch[1] + R.chip.offsetHeight + 6 - so[1]) + 'px';
      // window-space targets for the ghost cursor
      t.sfc = ctr(R.sf); t.chipc = ctr(R.chip); t.spdc = ctr(R.spd, .5, .5); t.moonc = ctr(R.moon); t.pipbc = ctr(R.pipb); t.s30 = ctr(slmI[2], .35, .5); t.pall = ctr(plmI[0], .35, .5);
      t.p0 = prs[0].offsetTop + prs[0].offsetHeight / 2; t.pitch = prs[1].offsetTop - prs[0].offsetTop; t.pv = R.pls.parentNode.offsetHeight;
      // playlists: natural cell boxes and panel boxes (relative to the layer)
      t.pl = pcells.map(function (c) { return off(c, R.pl); }); t.gw = pcells[0].offsetWidth; t.gh = pcells[0].offsetHeight;
      t.pn = plps.map(function (e) { var q = off(e, R.pl); return [q[0], q[1], e.offsetWidth, e.offsetHeight]; });
      t.wall = tiles.map(function (e) { return ctr(e); });
    }

    // ---------- library: filter with FLIP
    function visible(x, q, tab) { return q ? x.q.indexOf(q) > -1 : x.t === tab; }
    function hl(txt, q) { if (!q) return esc(txt); var i = nrm(txt).indexOf(q); return i < 0 ? esc(txt) : esc(txt.slice(0, i)) + '<mark>' + esc(txt.slice(i, i + q.length)) + '</mark>' + esc(txt.slice(i + q.length)); }
    function filt(qraw, tab) {
      var q = nrm(qraw.trim()), key = q + '|' + (q ? '' : tab) + '|' + nm();
      if (key === F.key) return; F.key = key;
      var first = null, flip = !S.rm && F.ready && win.animate && S.vis;
      if (flip) { first = new Map(); ITEMS.forEach(function (x) { if (!x.hide && x.el) first.set(x, off(x.el, win)); }); }
      var n = 0, g = {};
      ITEMS.forEach(function (x) {
        var v = visible(x, q, tab); x.hide = !v; x.el.hidden = !v;
        if (v) { n++; g[x.t] = 1; var a = x.t === 'l' ? [x.el.querySelector('.d-ln')] : [x.el.querySelector('.d-pt'), x.el.querySelector('.d-cap')]; a.forEach(function (e) { e.innerHTML = hl(x.name, q); }); }
      });
      var gc = Object.keys(g).length;
      secs.forEach(function (s) { var k = s.getAttribute('data-k'); s.hidden = !g[k]; s.classList.toggle('nh', gc < 2); });
      R.empty.hidden = n > 0; R.emq.textContent = q ? '“' + qraw.trim() + '”' : '';
      F.n = n; F.q = q; F.first = null;
      if (flip) {
        ITEMS.forEach(function (x) {
          if (x.hide) return; var b = off(x.el, win), a = first.get(x);
          if (!a) { x.el.animate([{ opacity: 0, transform: 'scale(.94)' }, { opacity: 1, transform: 'none' }], { duration: 320, easing: EASE }); return; }
          var dx = a[0] - b[0], dy = a[1] - b[1];
          if (dx || dy) x.el.animate([{ transform: 'translate(' + dx + 'px,' + dy + 'px)' }, { transform: 'none' }], { duration: 420, easing: EASE });
        });
      }
      F.ready = true;
      for (var i = 0; i < ITEMS.length; i++) if (!ITEMS[i].hide && ITEMS[i].t !== 'l') { F.first = ITEMS[i]; break; }
      if (!F.first) for (i = 0; i < ITEMS.length; i++) if (!ITEMS[i].hide) { F.first = ITEMS[i]; break; }
      F.tc = null;
    }
    function cats(tab) {
      var key = tab + nm() + S.sc; if (M.cats === key) return; M.cats = key;
      var h = nm() === 'he' ? 1 : 0, c = CAT[tab].map(function (n) { return '<div class="d-row d-ct">' + esc(n[h]) + '</div>'; }).join('');
      R.cats.innerHTML = c;
      R.cats2.innerHTML = [[0, 1], [1, 3], [3, 0]].map(function (g, i) { return '<div class="d-cs">' + PL[i][h] + '</div>' + g.map(function (k) { return '<div class="d-row d-ct">' + esc(CAT.m[k][h]) + '</div>'; }).join(''); }).join('');
    }

    // ---------- scenes
    var LAY = { search: { lib: 1 }, player: { vid: 1 }, pip: {}, playlists: { pl: 1 }, languages: { wall: 1 } };
    function layers(sc, p) {
      var o_ = { lib: 0, vid: 0, pl: 0, wall: 0 }, k;
      for (k in LAY[sc]) o_[k] = LAY[sc][k];
      if (sc === 'pip') { var u = ez(sg(p, .2, .42)); o_.lib = u; o_.vid = 1 - u; }
      ['lib', 'vid', 'pl', 'wall'].forEach(function (n) { st(R[n], 'opacity', o_[n]); cls(R[n], 'off', o_[n] < .01); });
    }
    function chrome(sc, p) {
      at(win, 'data-sc', sc);
      var tab = sc === 'search' ? (U.search && U.search.tab) || 'm' : 'm';
      segB.forEach(function (b) { var on_ = b.getAttribute('data-k') === tab; cls(b, 'on', on_); b.setAttribute('aria-pressed', on_); b.tabIndex = sc === 'search' ? 0 : -1; });
      cats(sc === 'search' ? tab : 'm'); F.tab = tab;
      var ed = sc === 'search'; R.inp.readOnly = !ed; R.inp.tabIndex = ed ? 0 : -1;
      if (!ed) { cls(R.sf, 'sm', true); cls(R.sf, 'fk', false); cls(R.sf, 'hv', false); tx(R.sim, ''); if (R.inp.value) R.inp.value = ''; if (sc === 'pip') filt('', 'm'); }
    }
    function qNow(p) {
      var u = U.search, a = Array.from(QRY[nm()] || QRY.en), n = 0, i;
      for (i = 0; i < a.length; i++) if (p >= .3 + i * .14) n = i + 1;
      return u && u.q != null ? u.q : a.slice(0, n).join('');
    }
    function cur(x, y, o_, click) {
      var c = R.cur, vis = o_ > .01 && !S.rm && (!S.pt || performance.now() - S.pt > 1600) && !drag;
      if (x != null) st(c, 'transform', 'translate3d(' + trunc(x, 10) + 'px,' + trunc(y, 10) + 'px,0)');
      st(c, 'opacity', vis ? trunc(o_, 100) : 0); cls(c, 'ck', click && vis);
    }
    function path(p, K_) { // K_: [[p, x, y], ...] eased between keys
      if (p <= K_[0][0]) return [K_[0][1], K_[0][2]];
      for (var i = 0; i < K_.length - 1; i++) { var a = K_[i], b = K_[i + 1]; if (p <= b[0]) { var t = ez(sg(p, a[0], b[0])); return [mix(a[1], b[1], t), mix(a[2], b[2], t)]; } }
      var l = K_[K_.length - 1]; return [l[1], l[2]];
    }
    function inR(p, a, b) { return p >= a && p <= b; }

    function rSearch(p) {
      var u = U.search, q = qNow(p), tab = F.tab;
      filt(q, tab);
      var sim = !(u && u.q != null), n = F.n, cnt = u && u.q != null ? 100000 : Math.round(100000 * eq(sg(p, .04, .56)));
      cls(R.sf, 'sm', sim); cls(R.sf, 'fk', sim && p >= .27 && p < .985); cls(R.sf, 'hv', !!q);
      tx(R.sim, sim ? q : ''); if (sim && R.inp.value !== q && D.activeElement !== R.inp) R.inp.value = q;
      var nf = NF[nm()] || (NF[nm()] = new Intl.NumberFormat(nm())); tx(R.cn, nf.format(cnt)); tx(R.ci, ' ' + xs('items'));
      tx(R.rs, q ? ' · ' + nf.format(n) + ' ' + xs(n === 1 ? 'one' : 'res') : '');
      at(R.cnt, 'aria-live', u && u.q != null ? 'polite' : 'off');
      cls(R.cnt, 'q', !!q);
      var hv = sim && p >= .9 && F.first; cells.forEach(function (c) { cls(c, 'hv', hv && c === F.first.el); }); rows.forEach(function (c) { cls(c, 'hv', hv && c === F.first.el); });
      // ghost cursor: to the search field, then (after typing) to the first result
      var t = M.t, a = [M.w * .78, M.h * .86], sf = t.sfc;
      if (sim && p < .36) { var c1 = path(p, [[.04, a[0], a[1]], [.2, sf[0] + 10, sf[1] + 4], [.3, sf[0] + 10, sf[1] + 4]]); cur(c1[0], c1[1], sg(p, .03, .08) * (1 - sg(p, .3, .36)), inR(p, .24, .29)); }
      else if (sim && p >= .76 && F.first) {
        if (!F.tc || F.tc[3] !== q) { var fr = off(F.first.el, win); F.tc = [fr[0] + F.first.el.offsetWidth * .5, fr[1] + F.first.el.offsetHeight * (F.first.t === 'l' ? .5 : .32), 0, q]; }
        var c2 = path(p, [[.76, sf[0] + 10, sf[1] + 4], [.9, F.tc[0], F.tc[1]]]); cur(c2[0], c2[1], sg(p, .76, .8), false);
      } else cur(null, null, 0);
      return;
    }

    function curSpeed(p) { var u = U.player; return u && u.speed != null ? u.speed : (S.sc === 'pip' ? 1 : trunc(1 + 2 * ez(sg(p, .5, .74)), 20)); }
    function curPos(p) { var u = U.player; return clamp((u && u.pos != null ? u.pos : S.sc === 'pip' ? 2105 : 1935 + 600 * p) + S.amb, 0, DUR); }
    function sfrac(v) { return clamp((v - .25) / 3.75, 0, 1); }
    function rVid(p, b) { // everything that depends on film time: frame, seek fill, time labels
      var pos = curPos(p), tau = pos / DUR, v = curSpeed(S.p.player), f = pos / DUR, t = M.t;
      var ba = b * 220 + S.ph * 50, cx = (b * 10 + S.ph * 1.3) % 50, sk = (b * 400 + S.ph * 160) % 100, so_ = S.paused || S.rm ? 0 : clamp((v - 1.25) / 2.5, 0, .75);
      paint(R.vf, tau, ba, cx, sk, so_);
      if (S.sc === 'pip') paint(R.pvf, tau, ba, cx, sk, so_);
      st(R.pf, 'transform', 'scaleX(' + trunc(f, 1000) + ')'); st(R.th, 'transform', 'translate3d(' + trunc(f * t.sk[2], 10) + 'px,0,0)');
      tx(R.tm, tcode(pos) + ' / ' + tcode(DUR));
      at(R.sk, 'aria-valuenow', Math.round(pos)); at(R.sk, 'aria-valuetext', tcode(pos) + ' / ' + tcode(DUR));
    }
    function rPlayer(p) {
      var u = U.player || {}, t = M.t, v = curSpeed(p), q = S.sc === 'player' ? p : 0;
      var sim = !U.player;
      var hov = H.hov != null ? H.hov : (q > .07 && q < .34 && u.pos == null ? mix(.12, .74, ez(sg(q, .08, .3))) : null);
      var bo = H.hov != null ? 1 : (hov != null ? sg(q, .07, .13) * (1 - sg(q, .27, .33)) : 0);
      var po = u.pop != null ? (u.pop ? 1 : 0) : sg(q, .38, .44) * (1 - sg(q, .8, .85));
      var mo = u.menu != null ? (u.menu ? 1 : 0) : sg(q, .88, .92) * (1 - sg(q, .955, .98));
      var sl = u.sleep != null ? u.sleep : (q >= .95 ? 30 : 0);
      // control bar
      cls(R.pp, 'pz', S.paused); R.pp.innerHTML = I(S.paused ? 'play' : 'pause', 'f'); R.pp._ic !== S.paused && (R.pp._ic = S.paused, at(R.pp, 'aria-label', xs(S.paused ? 'play' : 'pause')));
      tx(R.spd, fs(v)); cls(R.spd, 'fz', v !== 1); at(R.spd, 'aria-label', tr(8) + ' ' + fs(v)); at(R.spd, 'aria-expanded', po > .5 ? 'true' : 'false');
      cls(R.moon, 'fz', sl > 0); tx(R.zl, sl ? tr(15).replace('%d', sl) : ''); at(R.moon, 'aria-expanded', mo > .5 ? 'true' : 'false');
      // video
      rVid(p, S.sc === 'pip' ? .6 + .4 * S.p.pip : p);
      // hover bubble
      if (hov != null) {
        var bw = t.bubw, cx_ = t.sk[0] + hov * t.sk[2], left = clamp(cx_ - bw / 2, 8, M.sw - bw - 8), px = clamp(cx_ - left, 16, bw - 16);
        st(R.bub, 'transform', 'translate3d(' + trunc(left, 10) + 'px,' + trunc(t.ctl[1] - t.bubh - 9, 10) + 'px,0)'); sv(R.bub, '--px', trunc(px, 10) + 'px');
        paint(R.bf, hov, null); tx(R.bt, tshort(hov * DUR)); st(R.hf, 'transform', 'scaleX(' + trunc(hov, 1000) + ')'); st(R.mk, 'transform', 'translate3d(' + trunc(hov * t.sk[2], 10) + 'px,0,0)');
      }
      st(R.bub, 'opacity', trunc(bo, 100)); cls(R.sk, 'hv', hov != null && bo > .3); st(R.hf, 'opacity', bo > .3 ? 1 : 0); st(R.mk, 'opacity', bo > .3 ? 1 : 0);
      // speed popover
      st(R.pop, 'opacity', trunc(po, 100)); st(R.pop, 'transform', 'translate3d(0,' + trunc((1 - po) * 6, 10) + 'px,0) scale(' + trunc(mix(.94, 1, po), 1000) + ')'); cls(R.pop, 'off', po < .01);
      var fi = idxf(v);
      st(R.pls, 'transform', 'translate3d(0,' + trunc(t.pv / 2 - t.p0 - t.pitch * fi, 10) + 'px,0)');
      var nr = nearest(v); prs.forEach(function (r, i) { cls(r, 'on', Math.abs(SPEEDS[i] - v) < .001); var ti = po > .5 && SPEEDS[i] === nr ? 0 : -1; if (r.tabIndex !== ti) r.tabIndex = ti; });
      var sf_ = sfrac(v); st(R.rf, 'transform', 'scaleX(' + trunc(sf_, 1000) + ')'); st(R.rk, 'transform', 'translate3d(' + trunc(sf_ * t.rgw, 10) + 'px,0,0)');
      tx(R.rb, fs(v)); R.rst.disabled = v === 1; at(R.rg, 'aria-valuenow', v); at(R.rg, 'aria-valuetext', fs(v));
      // sleep menu
      st(R.slm, 'opacity', trunc(mo, 100)); st(R.slm, 'transform', 'translate3d(0,' + trunc((1 - mo) * 6, 10) + 'px,0) scale(' + trunc(mix(.94, 1, mo), 1000) + ')'); cls(R.slm, 'off', mo < .01);
      var hm = u.menu == null && q > .92 && q < .955 ? 2 : -1;
      slmI.forEach(function (b, i) { var m = +b.getAttribute('data-m'); cls(b, 'hv', i === hm); cls(b, 'on', m === sl); b.tabIndex = mo > .5 ? 0 : -1; });
      // controls fade (pip scene hides them when the video lifts out)
      st(R.vc, 'opacity', S.sc === 'pip' ? trunc(1 - sg(p, .1, .24), 100) : 1);
      // ghost cursor
      if (sim && S.sc === 'player') {
        var sk0 = function (f) { return [M.so[0] + t.sk[0] + f * t.sk[2], M.so[1] + t.sk[1] + t.sk[3] / 2]; }, th = function (v_) { return [t.rgx[0] + sfrac(v_) * t.rgw, t.rgx[1] + t.rgh / 2]; },
          a = [M.w * .8, M.h * .52], z = [M.w * .86, M.h * .66], k1 = sk0(.12), k2 = sk0(.74), t1 = th(1), t3 = th(3), pl = t.spdc, mn = t.moonc, mr = t.s30;
        var c = path(p, [[.02, a[0], a[1]], [.08, k1[0], k1[1]], [.3, k2[0], k2[1]], [.36, pl[0], pl[1]], [.42, pl[0], pl[1]], [.49, t1[0], t1[1]], [.74, t3[0], t3[1]], [.8, t3[0], t3[1]], [.86, mn[0], mn[1]], [.91, mn[0], mn[1]], [.945, mr[0], mr[1]], [.975, mr[0], mr[1]], [1, z[0], z[1]]]);
        cur(c[0], c[1], sg(p, .01, .06) * (1 - sg(p, .985, 1)), inR(p, .36, .4) || inR(p, .87, .9) || inR(p, .945, .97));
      } else if (S.sc === 'player') cur(null, null, 0);
    }
    function idxf(v) { var i = 0; while (i < SPEEDS.length - 2 && v >= SPEEDS[i + 1]) i++; return i + clamp((v - SPEEDS[i]) / (SPEEDS[i + 1] - SPEEDS[i]), 0, 1); }

    var PTS = [[.5, .5], [.7, .6], [.3, .6], [.34, .28], [.64, .26], [.8, .7]], PW = .3;
    function pipBox(p) {
      var sw = M.sw, sh = M.sh, pw = Math.round(sw * PW), ph = pw * 9 / 16, em = M.em, u = U.pip, k = mix(sw / pw, 1, ez(sg(p, .18, .42))), mg = 1.4 * em;
      var P = PTS.map(function (a, i) { return i === PTS.length - 1 ? [(sw - pw / 2 - mg) / sw, (sh - ph / 2 - mg) / sh] : a; });
      var c = spl(P, ez(sg(p, .18, .93))), x = c[0] * sw - pw * k / 2, y = c[1] * sh - ph * k / 2;
      if (u && u.x != null) { x = u.x; y = u.y; k = 1; }
      return { x: x, y: y, k: k, pw: pw, ph: ph, c: c };
    }
    function rPip(p) {
      var u = U.pip || {}, b = pipBox(p), t = M.t, pw = b.pw;
      var hid_ = u.hide || p < .17; st(R.pip, 'opacity', hid_ ? 0 : 1); cls(R.pip, 'off', !!hid_);
      st(R.pip, 'width', pw + 'px'); st(R.pip, 'transform', 'translate3d(' + trunc(b.x, 10) + 'px,' + trunc(b.y, 10) + 'px,0) scale(' + trunc(b.k, 1000) + ')'); sv(R.pip, '--k', trunc(b.k, 1000)); sv(R.pip, '--lf', trunc(sg(b.k, 3, 1) * (u.x != null ? 1 : 1), 100));
      cls(R.pip, 'sc', b.k > 1.04); cls(R.pip, 'hv', u.x == null && p > .94 || u.x != null && !!u.hov); at(R.pip, 'aria-hidden', hid_ ? 'true' : 'false');
      R.ppp.innerHTML = I(S.paused ? 'play' : 'pause', 'f');
      rPlayer(p);
      // toolbar button highlight + cursor: PiP button, then carrying the window around the wall
      var pb = t.pipbc, a = [M.w * .82, M.h * .4];
      cls(R.pipb, 'ak', p > .12 && p < .2);
      if (!U.pip) {
        var grab = [M.so[0] + b.c[0] * M.sw, M.so[1] + b.c[1] * M.sh - b.ph * b.k / 2 + 1.6 * M.em], rest = [M.so[0] + b.x + b.pw / 2, M.so[1] + b.y + b.ph * .55];
        var c = p < .26 ? path(p, [[.02, a[0], a[1]], [.12, pb[0], pb[1]], [.19, pb[0], pb[1]], [.26, pb[0] + 10, pb[1] + 6]]) : p < .93 ? grab : path(p, [[.93, grab[0], grab[1]], [.99, rest[0] + 10, rest[1]]]);
        cur(c[0], c[1], sg(p, .01, .06) * (1 - sg(p, .995, 1)), inR(p, .13, .18) || inR(p, .27, .3));
      } else cur(null, null, 0);
    }

    function rPl(p) {
      var u = U.playlists || {}, t = M.t, m = u.pl != null ? 1 : sg(p, .34, .7), n = PLITEMS.length, ip = .8 * M.em, hh = 4.2 * M.em, gap = .8 * M.em;
      var all = u.pl == null || u.pl === 'all', menu = u.menu != null ? (u.menu ? 1 : 0) : sg(p, .14, .19) * (1 - sg(p, .34, .38));
      var merged = u.pl != null ? true : p >= .35;
      var po = 1 - eo(sg(m, 0, .5));
      plps.forEach(function (e, i) { st(e, 'opacity', trunc(po, 100)); st(e, 'transform', 'translate3d(0,' + trunc((1 - po) * -8, 10) + 'px,0)'); });
      var cw = (t.pn[0][2] - 2 * ip - gap) / 2, s = clamp(cw / t.gw, .3, 1);
      var rank = PLITEMS.map(function (x, i) { return i; }).filter(function (i) { return all || PLITEMS[i].pl === u.pl; }); cls(R.pl, 'us', u.pl != null);
      PLITEMS.forEach(function (x, i) {
        var a = x.pl, k = (i / 3) | 0, col = k % 2, row = (k / 2) | 0, e = u.pl != null ? 1 : ez(sg(m, i * .02, .58 + i * .02)), pn = t.pn[a];
        var tx_ = pn[0] + ip + col * (cw + gap), ty = pn[1] + hh + row * (t.gw * 1.5 * s + gap), gx = t.pl[i][0], gy = t.pl[i][1];
        var shown = u.pl == null || u.pl === 'all' || u.pl === a, j = rank.indexOf(i), ox = shown && j > -1 ? t.pl[j][0] - gx : 0, oy = shown && j > -1 ? t.pl[j][1] - gy : 0;
        st(x.el, 'transform', 'translate3d(' + trunc((tx_ - gx) * (1 - e) + (u.pl != null ? ox : 0), 10) + 'px,' + trunc((ty - gy) * (1 - e) + (u.pl != null ? oy : 0), 10) + 'px,0) scale(' + trunc(mix(s, 1, e), 1000) + ')');
        st(x.el, 'opacity', shown ? 1 : .0); cls(x.el, 'dim', !shown);
        st(x.el.lastChild, 'opacity', trunc(sg(e, .55, 1), 100));
        var bd = x.bd, bo = all ? ez(sg(p, .58 + i * .006, .7 + i * .006)) : 0; if (u.pl != null && all) bo = 1;
        tx(bd, PL[a][nm() === 'he' ? 1 : 0]); st(bd, 'opacity', trunc(bo, 100)); st(bd, 'transform', 'scale(' + trunc(mix(.6, 1, bo), 100) + ')');
      });
      // chip + menu + sidebar
      var cn = merged ? (all ? tr(13) : PL[u.pl][nm() === 'he' ? 1 : 0]) : PL[0][nm() === 'he' ? 1 : 0];
      if (R.chipn._tx !== cn) { tx(R.chipn, cn); if (!S.rm && R.chip.animate && F.ready) R.chipn.animate([{ opacity: 0, transform: 'translateY(.3em)' }, { opacity: 1, transform: 'none' }], { duration: 300, easing: EASE }); M.dirty = true; }
      at(R.chip, 'aria-expanded', menu > .5 ? 'true' : 'false'); cls(R.chip, 'ak', menu > .5);
      st(R.plm, 'opacity', trunc(menu, 100)); st(R.plm, 'transform', 'translate3d(0,' + trunc((1 - menu) * -6, 10) + 'px,0) scale(' + trunc(mix(.95, 1, menu), 1000) + ')'); cls(R.plm, 'off', menu < .01);
      var sel = merged ? (all ? 'all' : u.pl) : 0, hv = u.menu == null && u.pl == null && p > .26 && p < .37 ? 'all' : null;
      plmI.forEach(function (b, i) { var k = b.getAttribute('data-pl'); cls(b, 'on', String(sel) === k); cls(b, 'hv', hv === k); b.tabIndex = menu > .5 ? 0 : -1; });
      var e2 = u.pl != null ? (all ? 1 : 0) : sg(p, .45, .66); st(R.cats, 'opacity', trunc(u.pl != null ? 1 - e2 : 1 - sg(p, .44, .53), 100)); st(R.cats2, 'opacity', trunc(u.pl != null ? e2 : sg(p, .53, .64), 100));
      // cursor
      if (!U.playlists) {
        var ch = t.chipc, ar = t.pall, a = [M.w * .74, M.h * .84];
        var c = path(p, [[.02, a[0], a[1]], [.12, ch[0], ch[1]], [.17, ch[0], ch[1]], [.26, ar[0], ar[1]], [.37, ar[0], ar[1]], [.5, M.w * .62, M.h * .74], [1, M.w * .66, M.h * .8]]);
        cur(c[0], c[1], sg(p, .01, .06) * (1 - sg(p, .46, .56)), inR(p, .125, .16) || inR(p, .32, .35));
      } else cur(null, null, 0);
    }

    var SEQ = [[.1, 'he'], [.28, 'ar'], [.46, 'ja'], [.62, 'hi'], [.78, 'ru'], [.9, '@']];
    function rLang(p) {
      var u = U.languages, l = '@', i, ki = -1;
      for (i = 0; i < SEQ.length; i++) if (p >= SEQ[i][0]) { l = SEQ[i][1]; ki = i; }
      l = u && u.lang ? u.lang : l === '@' ? S.base : l;
      if (S.lang !== l) { S.lang = l; applyLang(true); }
      tiles.forEach(function (e) { var ti = e.getAttribute('data-l') === S.lang ? 0 : -1; if (e.tabIndex !== ti) e.tabIndex = ti; });
      if (!u) {
        var t = M.t, K_ = [[0, M.w * .7, M.h * .9]];
        SEQ.forEach(function (s) { if (s[1] === '@') return; var j = LANGS.findIndex(function (q) { return q[0] === s[1]; }), c = t.wall[j]; c = [c[0] + M.so[0], c[1] + M.so[1]]; K_.push([s[0] - .035, c[0], c[1]]); K_.push([s[0] + .1, c[0] + 6, c[1] + 4]); });
        K_.sort(function (a, b) { return a[0] - b[0]; });
        var c2 = path(p, K_); cur(c2[0], c2[1], sg(p, .01, .05) * (1 - sg(p, .9, .97)), false);
      } else cur(null, null, 0);
    }

    // ---------- render
    function render() {
      if (S.dead) return;
      if (M.dirty) measure();
      if (M.dirty) return;
      var sc = S.sc, p = S.rm ? Math.round(S.p[sc] * 4) / 4 : S.p[sc];
      if (sc !== 'languages' && S.lang !== S.base && !(U.languages && U.languages.lang)) { S.lang = S.base; applyLang(); }
      layers(sc, p); chrome(sc, p);
      if (M.dirty) measure();
      cls(win, 'rm', S.rm); cls(ITEMS[11].el, 'now', sc === 'pip');
      ({ search: rSearch, player: rPlayer, pip: rPip, playlists: rPl, languages: rLang })[sc](p);
      if (M.dirty) { measure(); }
    }

    // ---------- loop (only while there is something that moves)
    function ambOn() { return !S.rm && S.vis && !D.hidden && !S.paused && (S.sc === 'player' || (S.sc === 'pip' && S.p.pip > .15 && !(U.pip && U.pip.hide))); }
    function tick(t) {
      raf = 0; if (S.dead) return;
      var dt = Math.min(.05, (t - last) / 1000); last = t; var run = false;
      if (tw) { var k = clamp((t - tw.t0) / tw.d, 0, 1); S.p[tw.sc] = mix(tw.a, tw.b, ez(k)); if (k >= 1) { var dn = tw.done; tw = null; if (dn) dn(); } render(); run = true; }
      if (fx) { run = inertia(dt) || run; }
      if (ambOn()) { var v = curSpeed(S.p.player); S.amb += dt * v; S.ph += dt * v; if (!tw) { rVid(S.p[S.sc], S.sc === 'pip' ? .6 + .4 * S.p.pip : S.p.player); } run = true; }
      if (run) raf = requestAnimationFrame(tick);
    }
    function kick() { if (!raf && !S.dead && !D.hidden) { last = performance.now(); raf = requestAnimationFrame(tick); } }
    function tween(sc, to, d, done) { if (S.rm) { S.p[sc] = to; render(); if (done) done(); return; } tw = { sc: sc, a: S.p[sc], b: to, t0: performance.now(), d: d, done: done }; kick(); }
    function inertia(dt) {
      var u = U.pip; if (!u || !fx || drag) return false;
      var vx = fx.vx, vy = fx.vy, f = Math.pow(.003, dt); fx.vx *= f; fx.vy *= f;
      var b = clampPip(u.x + vx * dt, u.y + vy * dt); u.x = b[0]; u.y = b[1]; if (b[2]) fx.vx *= -.4; if (b[3]) fx.vy *= -.4;
      render();
      if (Math.abs(fx.vx) + Math.abs(fx.vy) < 12) { fx = 0; return false; }
      return true;
    }
    function clampPip(x, y) { var pw = Math.round(M.sw * PW), ph = pw * 9 / 16, m = .6 * M.em, cx = clamp(x, m, M.sw - pw - m), cy = clamp(y, m, M.sh - ph - m); return [cx, cy, cx !== x, cy !== y]; }

    // ---------- interactions
    function closePop() { var u = U.player; if (u && (u.pop || u.menu)) { u.pop = false; u.menu = false; req(); } if (U.playlists && U.playlists.menu) { U.playlists.menu = false; req(); } }
    function nearest(f) { var best = SPEEDS[0]; SPEEDS.forEach(function (v) { if (Math.abs(v - f) < Math.abs(best - f)) best = v; }); return best; }
    function setSpeed(v, snap) { v = clamp(Math.round(v * 20) / 20, .25, 4); var n = nearest(v); if (snap !== false && Math.abs(n - v) < .06) v = n; usr('player').speed = v; req(); kick(); }
    function seekTo(f) { var u = usr('player'); u.pos = clamp(f, 0, 1) * DUR; S.amb = 0; req(); }
    function fracOf(el, e) { var r = el.getBoundingClientRect(); return clamp((e.clientX - r.left) / (r.width || 1), 0, 1); }
    function ptr(el, fn, end) { // press + drag on an element, Esc cancels
      on(el, 'pointerdown', function (e) { if (e.button) return; el.setPointerCapture(e.pointerId); el._pid = e.pointerId; el._d = 1; fn(e); e.preventDefault(); });
      on(el, 'pointermove', function (e) { if (el._d) fn(e); });
      var up = function (e) { if (el._d) { el._d = 0; if (end) end(e); } }; on(el, 'pointerup', up); on(el, 'pointercancel', up); on(el, 'lostpointercapture', up);
    }
    on(win, 'pointermove', function () { S.pt = performance.now(); });
    on(win, 'pointerleave', function () { S.pt = 0; });
    on(R.sk, 'pointermove', function (e) { if (S.sc !== 'player') return; H.hov = fracOf(R.sk, e); req(); });
    on(R.sk, 'pointerleave', function () { if (!R.sk._d) { H.hov = null; req(); } });
    ptr(R.sk, function (e) { H.hov = fracOf(R.sk, e); seekTo(H.hov); }, function () { H.hov = null; req(); });
    on(R.sk, 'keydown', function (e) {
      var d = { ArrowLeft: -10, ArrowRight: 10, ArrowDown: -10, ArrowUp: 10, PageDown: -60, PageUp: 60 }[e.key], cp = curPos(S.p.player) - S.amb;
      if (d != null) { usr('player').pos = clamp(curPos(S.p.player) + d, 0, DUR); S.amb = 0; req(); e.preventDefault(); }
      else if (e.key === 'Home' || e.key === 'End') { usr('player').pos = e.key === 'Home' ? 0 : DUR - 1; S.amb = 0; req(); e.preventDefault(); }
    });
    function skip(d) { usr('player').pos = clamp(curPos(S.p.player) + d, 0, DUR); S.amb = 0; req(); }
    on(R.bw, 'click', function () { skip(-10); }); on(R.fw, 'click', function () { skip(10); });
    on(R.pp, 'click', function () { S.paused = !S.paused; req(); kick(); }); on(R.ppp, 'click', function () { S.paused = !S.paused; req(); kick(); });
    on(R.spd, 'click', function () { var u = usr('player'), cur_ = u.pop != null ? u.pop : (S.p.player > .5 && S.p.player < .84); u.pop = !cur_; u.menu = false; req(); if (u.pop) setTimeout(function () { var s = prs.filter(function (r) { return r.classList.contains('on'); })[0] || prs[3]; try { s.focus({ preventScroll: true }); } catch (e) {} }, 40); });
    prs.forEach(function (r) { on(r, 'click', function () { setSpeed(+r.getAttribute('data-v'), false); usr('player').pop = false; R.spd.focus({ preventScroll: true }); }); });
    on(R.rst, 'click', function () { setSpeed(1, false); usr('player').pop = false; R.spd.focus({ preventScroll: true }); });
    on(R.pls, 'keydown', function (e) { var d = e.key === 'ArrowDown' ? 1 : e.key === 'ArrowUp' ? -1 : 0, i = prs.indexOf(D.activeElement); if (d && i > -1) { prs[clamp(i + d, 0, prs.length - 1)].focus({ preventScroll: true }); e.preventDefault(); } });
    ptr(R.rg, function (e) { setSpeed(.25 + fracOf(R.rg, e) * 3.75); });
    on(R.rg, 'keydown', function (e) { var v = curSpeed(S.p.player), d = { ArrowLeft: -.05, ArrowRight: .05, ArrowDown: -.05, ArrowUp: .05, PageUp: .25, PageDown: -.25 }[e.key]; if (d != null) { setSpeed(v + d, false); e.preventDefault(); } else if (e.key === 'Home') { setSpeed(.25, false); e.preventDefault(); } else if (e.key === 'End') { setSpeed(4, false); e.preventDefault(); } });
    on(R.moon, 'click', function () { var u = usr('player'), cm = u.menu != null ? u.menu : (S.p.player > .9 && S.p.player < .965); u.menu = !cm; u.pop = false; req(); if (u.menu) setTimeout(function () { try { slmI[2].focus({ preventScroll: true }); } catch (e) {} }, 40); });
    slmI.forEach(function (b) { on(b, 'click', function () { var u = usr('player'); u.sleep = +b.getAttribute('data-m'); u.menu = false; req(); R.moon.focus({ preventScroll: true }); }); });
    on(D, 'pointerdown', function (e) { var u = U.player; if (u && (u.pop || u.menu) && !e.target.closest('.d-pop,.d-slm,.d-spd,.d-moon')) closePop(); if (U.playlists && U.playlists.menu && !e.target.closest('.d-plm,.d-chip')) closePop(); }, true);
    on(win, 'keydown', function (e) {
      if (e.key !== 'Escape') return;
      if (S.info) { closeInfo(); e.stopPropagation(); return; }
      if (drag) { drag.cancel(); e.stopPropagation(); return; }
      var dd = [R.sk, R.rg].filter(function (x) { return x._d; }); if (dd.length) { dd.forEach(function (x) { x._d = 0; try { x.releasePointerCapture(x._pid); } catch (er) {} }); H.hov = null; req(); e.stopPropagation(); return; }
      var u = U.player, op = (u && (u.pop || u.menu)) || (U.playlists && U.playlists.menu);
      if (op) { closePop(); (u && u.pop === false ? R.spd : R.chip).focus({ preventScroll: true }); e.stopPropagation(); }
    });
    // player -> PiP
    on(R.pipb, 'click', function () { if (S.sc === 'pip') return; U.player = null; S.p.pip = 0; setScene('pip', { instant: true }); tween('pip', 1, 2800); });
    on(R.pre, 'click', function () { U.pip = null; fx = 0; tween('pip', 0, 1300); });
    on(R.pcl, 'click', function () { usr('pip').hide = true; req(); });

    // PiP window: drag, keyboard, inertia, Esc releases
    on(R.pip, 'pointerdown', function (e) {
      if (e.button || R.pip.classList.contains('sc')) return;
      var b = pipBox(S.p.pip), u = usr('pip'), x0 = u.x != null ? u.x : b.x, y0 = u.y != null ? u.y : b.y, started = false;
      var sx = e.clientX, sy = e.clientY, pid = e.pointerId, lt = performance.now(), lx = sx, ly = sy, vx = 0, vy = 0, sc_ = win.offsetWidth ? win.getBoundingClientRect().width / win.offsetWidth : 1;
      var begin = function () { started = true; u.x = x0; u.y = y0; R.pip.setPointerCapture(pid); R.pip.classList.add('dg'); fx = 0; drag = { cancel: function () { done(true); } }; };
      var mv = function (ev) {
        if (ev.pointerId !== pid) return;
        if (!started) { if (Math.abs(ev.clientX - sx) + Math.abs(ev.clientY - sy) < 5) return; begin(); }
        var c = clampPip(x0 + (ev.clientX - sx) / sc_, y0 + (ev.clientY - sy) / sc_); u.x = c[0]; u.y = c[1];
        var now = performance.now(), dt = Math.max(1, now - lt) / 1000; vx = mix(vx, (ev.clientX - lx) / sc_ / dt, .5); vy = mix(vy, (ev.clientY - ly) / sc_ / dt, .5); lt = now; lx = ev.clientX; ly = ev.clientY; req();
      };
      var done = function (cancel) {
        R.pip.removeEventListener('pointermove', mv); R.pip.removeEventListener('pointerup', up); R.pip.removeEventListener('pointercancel', up); R.pip.classList.remove('dg'); drag = null;
        try { R.pip.releasePointerCapture(pid); } catch (er) {}
        if (started) { var kill = function (ev) { ev.stopPropagation(); ev.preventDefault(); }; R.pip.addEventListener('click', kill, { capture: true, once: true }); setTimeout(function () { R.pip.removeEventListener('click', kill, true); }, 60); }
        if (cancel) { u.x = x0; u.y = y0; req(); } else if (started && !S.rm && Math.abs(vx) + Math.abs(vy) > 160) { fx = { vx: clamp(vx, -2200, 2200) * .5, vy: clamp(vy, -2200, 2200) * .5 }; kick(); }
        req();
      };
      var up = function (ev) { if (ev.pointerId === pid) done(false); };
      R.pip.addEventListener('pointermove', mv); R.pip.addEventListener('pointerup', up); R.pip.addEventListener('pointercancel', up);
      if (!e.target.closest('button')) { e.preventDefault(); }
    });
    on(R.pip, 'keydown', function (e) {
      var d = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }[e.key]; if (!d) return;
      var b = pipBox(S.p.pip), u = usr('pip'), st_ = (e.shiftKey ? 96 : 24); var c = clampPip((u.x != null ? u.x : b.x) + d[0] * st_, (u.y != null ? u.y : b.y) + d[1] * st_); u.x = c[0]; u.y = c[1]; req(); e.preventDefault();
    });
    on(R.pip, 'pointerenter', function () { usr('pip').hov = 1; req(); }); on(R.pip, 'pointerleave', function () { if (U.pip) { U.pip.hov = 0; req(); } });
    on(R.pip, 'focusin', function () { if (U.pip) U.pip.hov = 1; req(); });

    // search
    on(R.inp, 'focus', function () { if (S.sc !== 'search') return; var u = usr('search'); if (u.q == null) { u.q = qNow(S.p.search); S.amb = 0; } R.inp.value = u.q; req(); });
    on(R.inp, 'input', function () { usr('search').q = R.inp.value; req(); });
    on(R.inp, 'keydown', function (e) { if (e.key === 'Enter' && F.first) { openInfo(F.first); e.preventDefault(); return; } if (e.key === 'Escape' && R.inp.value) { R.inp.value = ''; usr('search').q = ''; req(); e.stopPropagation(); } });
    on(R.clr, 'click', function () { usr('search').q = ''; R.inp.value = ''; req(); R.inp.focus(); });
    on(R.sf, 'pointerdown', function (e) { if (S.sc === 'search' && e.target !== R.inp) { e.preventDefault(); R.inp.focus(); } });
    segB.forEach(function (b) { on(b, 'click', function () { if (S.sc !== 'search') return; var u = usr('search'); u.tab = b.getAttribute('data-k'); if (u.q == null) u.q = ''; req(); }); });
    // playlists menu
    on(R.chip, 'click', function () { if (S.sc !== 'playlists') return; var u = usr('playlists'), cm = u.menu != null ? u.menu : (S.p.playlists > .17 && S.p.playlists < .46); u.menu = !cm; req(); if (u.menu) setTimeout(function () { try { plmI[0].focus({ preventScroll: true }); } catch (e) {} }, 40); });
    plmI.forEach(function (b) { on(b, 'click', function () { var u = usr('playlists'), k = b.getAttribute('data-pl'); u.pl = k === 'all' ? 'all' : +k; u.menu = false; req(); R.chip.focus({ preventScroll: true }); }); });
    // language wall: hover or focus re-labels the mock, click keeps it, arrows move
    function pickLang(l) { var u = usr('languages'); if (u.lang === l) return; u.lang = l; S.lang = l; applyLang(true); req(); }
    tiles.forEach(function (t, i) {
      var l = t.getAttribute('data-l');
      on(t, 'pointerenter', function (e) { if (e.pointerType !== 'touch') pickLang(l); }); on(t, 'focus', function () { pickLang(l); }); on(t, 'click', function () { pickLang(l); });
      on(t, 'keydown', function (e) {
        var d = { ArrowRight: 1, ArrowLeft: -1, ArrowDown: 5, ArrowUp: -5 }[e.key]; if (d == null) return;
        var n = tiles[clamp(i + d, 0, tiles.length - 1)]; n.focus({ preventScroll: true }); e.preventDefault();
      });
    });
    // details sheet: opens from a poster click or Enter in the search field (the title data is invented)
    var INFO = {
      en: { pl: ['A quiet coastal town keeps a promise it made decades ago, and one winter night the promise comes due.', 'When a signal arrives from a station that was shut down years ago, a small crew has to decide whether to answer.', 'A small cloud, a curious fox and a very long way home.', 'Everything that can go wrong on the big day goes wrong, in the kindest possible way.', 'Season after season, the people of one street learn that every ordinary evening hides a story.'],
        cast: ['Maya Lindqvist, Tomas Reyes, Noor Haddad', 'Elena Voss, Jonah Park, Ravi Anand', 'Sofia Marchetti, Leo Brandt, Aiko Mori'], dir: ['Ines Calloway', 'Marek Dvorak', 'Hana Ibsen'], cty: ['Iceland', 'Portugal', 'Canada', 'Japan'],
        L: { plot: 'Plot', cast: 'Cast', dir: 'Director', cty: 'Country', play: 'Play', close: 'Close', h: 'h' } },
      he: { pl: ['עיירת חוף שקטה מקיימת הבטחה מלפני עשורים, ובליל חורף אחד מגיע זמן הפירעון.', 'כשמגיע אות מתחנה שנסגרה לפני שנים, צוות קטן צריך להחליט אם להשיב.', 'ענן קטן, שועל סקרן ודרך ארוכה מאוד הביתה.', 'כל מה שיכול להשתבש ביום הגדול משתבש, בצורה הנדיבה ביותר.', 'עונה אחרי עונה, תושבי רחוב אחד לומדים שמאחורי כל ערב רגיל מסתתר סיפור.'],
        cast: ['מאיה לינדקוויסט, תומס רייס, נור חדאד', 'אלנה פוס, יונה פארק, ראווי אנאנד', 'סופיה מרקטי, ליאו ברנדט, אייקו מורי'], dir: ['אינס קאלווי', 'מארק דבורז׳ק', 'הנה איבסן'], cty: ['איסלנד', 'פורטוגל', 'קנדה', 'יפן'],
        L: { plot: 'תקציר', cast: 'שחקנים', dir: 'במאי', cty: 'מדינה', play: 'נגן', close: 'סגור', h: 'שע׳' } }
    };
    function openInfo(it) {
      if (!it || it.t === 'l' || S.info) return;
      var D_ = INFO[nm()], L = D_.L, he = nm() === 'he', k = it.i, c = it.t === 's' ? 4 : it.c, mins = 82 + (k * 13) % 46, rt = (6.6 + (k * 37) % 18 / 10).toFixed(1), gn = CAT[it.t][it.c][he ? 1 : 0];
      R.spz.innerHTML = '<div class="d-pz" style="--h:' + it.h + '"><b class="d-pt">' + esc(it.name) + '</b><small class="d-pg">' + esc(gn) + '</small></div>';
      R.sti.textContent = it.name;
      R.smeta.innerHTML = (it.y ? '<span>' + it.y + '</span>' : '') + '<span class="d-rate">' + I('star', 'f') + '<i>' + rt + '</i></span><span>' + ((mins / 60) | 0) + ' ' + L.h + ' ' + tr(15).replace('%d', mins % 60) + '</span><span>' + esc(gn) + '</span>';
      R.splay.lastChild.textContent = L.play; R.scl.textContent = L.close;
      R.sinfo.innerHTML = '<h5>' + L.plot + '</h5><p>' + D_.pl[c] + '</p><dl><dt>' + L.dir + '</dt><dd>' + D_.dir[k % 3] + '</dd><dt>' + L.cast + '</dt><dd>' + D_.cast[k % 3] + '</dd><dt>' + L.cty + '</dt><dd>' + D_.cty[k % 4] + '</dd></dl>';
      R.sdlg.setAttribute('aria-label', it.name); S.info = it; S.focusBack = D.activeElement;
      R.sheet.classList.remove('off');
      if (S.rm) R.sheet.classList.add('on'); else requestAnimationFrame(function () { R.sheet.classList.add('on'); });
      try { R.scl.focus({ preventScroll: true }); } catch (e) {}
    }
    function closeInfo(quiet) {
      if (!S.info) return; S.info = null; R.sheet.classList.remove('on'); R.sheet.classList.add('off');
      if (!quiet && S.focusBack && S.focusBack !== D.body && win.contains(S.focusBack)) try { S.focusBack.focus({ preventScroll: true }); } catch (e) {}
    }
    on(R.scl, 'click', function () { closeInfo(); });
    on(R.sheet, 'pointerdown', function (e) { if (e.target === R.sheet) closeInfo(); });
    on(win, 'click', function (e) { var c = e.target.closest && e.target.closest('.d-lib .d-pc'); if (c && c._it && (S.sc === 'search' || (S.sc === 'pip' && S.p.pip > .5))) openInfo(c._it); });
    // visibility: pause everything off screen
    var io = W.IntersectionObserver ? new IntersectionObserver(function (en) { S.vis = en[en.length - 1].isIntersecting; if (S.vis) { M.dirty = true; render(); kick(); } }) : null;
    if (io) io.observe(root);
    var ro = W.ResizeObserver ? new ResizeObserver(function () { M.dirty = true; req(); }) : null;
    if (ro) ro.observe(win);
    on(D, 'visibilitychange', function () { if (!D.hidden) kick(); });
    if (mq) { var mh = function () { if (o.reducedMotion == null) setRM(mq.matches); }; mq.addEventListener ? mq.addEventListener('change', mh) : 0; offs.push(function () { mq.removeEventListener && mq.removeEventListener('change', mh); }); }

    // ---------- API
    function setRM(b) { S.rm = !!b; if (S.rm) { tw = null; fx = 0; } M.dirty = true; render(); kick(); }
    function setScene(n, opt) {
      if (SCENES.indexOf(n) < 0) return;
      opt = opt || {};
      if (n === S.sc && !opt.force) return;
      var old = S.sc; closeInfo(true); U[old] = null; H.hov = null; if (U.playlists) U.playlists = null; S.amb = 0; fx = 0; tw = (tw && tw.sc === n) ? tw : null;
      S.sc = n; S.lang = S.base; applyLang(false); if (n !== 'pip') S.paused = false;
      if (!opt.instant && !S.rm) { win.classList.add('d-sw'); clearTimeout(swT); swT = setTimeout(function () { win.classList.remove('d-sw'); }, 560); } else { win.classList.remove('d-sw'); }
      M.dirty = true; render(); kick();
    }
    function setProgress(n, p) {
      if (SCENES.indexOf(n) < 0) return; p = clamp(+p || 0, 0, 1);
      if (S.sc !== n) setScene(n);
      if (S.info && Math.abs(p - S.p[n]) > .012) closeInfo(true);
      var u = U[n]; if (u && Math.abs(p - u._p) > .012) { U[n] = null; H.hov = null; fx = 0; if (n === 'languages') { S.lang = S.base; applyLang(true); } }
      if (Math.abs(p - S.p[n]) > .0005) S.amb = 0;
      S.p[n] = p; tw = null; render(); kick();
    }
    function setLang(l) { l = nl(l); S.base = l; S.lang = l; win._l = null; setNames(); applyLang(false); M.dirty = true; render(); }
    function destroy() {
      if (S.dead) return; S.dead = true; cancelAnimationFrame(raf); cancelAnimationFrame(qf); clearTimeout(swT);
      offs.forEach(function (f) { f(); }); if (io) io.disconnect(); if (ro) ro.disconnect();
      if (win.parentNode) win.parentNode.removeChild(win);
      hid.forEach(function (a) { a[0].hidden = a[1]; });
      root.removeAttribute('data-iptvdemo'); rold[0] == null ? root.removeAttribute('role') : root.setAttribute('role', rold[0]); rold[1] == null ? root.removeAttribute('aria-label') : root.setAttribute('aria-label', rold[1]);
      delete root.__iptvdemo;
    }
    function getState() {
      var u = U[S.sc] || {}, p = S.p[S.sc], q = S.sc === 'search' ? qNow(p) : null;
      return { scene: S.sc, progress: p, lang: S.lang, base: S.base, dir: win.dir, query: q, results: S.sc === 'search' ? F.n : null, speed: S.sc === 'player' || S.sc === 'pip' ? curSpeed(p) : null,
        pos: S.sc === 'player' ? Math.round(curPos(p)) : null, sleep: u.sleep != null ? u.sleep : (S.sc === 'player' && p >= .95 ? 30 : 0), user: !!U[S.sc], reducedMotion: S.rm };
    }

    setNames(); applyLang(false); setScene('search', { force: true, instant: true });
    var api = { destroy: destroy, setScene: setScene, setLang: setLang, setProgress: setProgress, getState: getState, setReducedMotion: setRM, scenes: SCENES.slice() };
    root.__iptvdemo = api;
    return api;
  }

  W.IPTVDemo = { mount: mount, scenes: SCENES.slice(), languages: LANGS.map(function (l) { return l[0]; }) };
})(window, document);
