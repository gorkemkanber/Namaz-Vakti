
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifications = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(const InitializationSettings(android: androidInit));
  runApp(MyApp(notifications: notifications));
}

class MyApp extends StatelessWidget {
  final FlutterLocalNotificationsPlugin notifications;
  MyApp({required this.notifications});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PrayerModel(notifications)),
      ],
      child: MaterialApp(
        title: 'Namaz Vakti',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.light,
        ),
        home: HomePage(),
      ),
    );
  }
}

class PrayerModel extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin notifications;
  Map<String, DateTime> prayers = {};
  String city = 'Gaziantep';
  Timer? _ticker;
  String nextPrayerLabel = '';
  Duration timeUntilNext = Duration.zero;

  PrayerModel(this.notifications) {
    loadPrefs();
    // initial fetch
    fetchPrayerTimes();
    // update remaining time every second
    _ticker = Timer.periodic(Duration(seconds: 1), (_) => _updateNext());
  }

  Future<void> loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    city = p.getString('city') ?? 'Gaziantep';
  }

  Future<void> savePrefs() async {
    final p = await SharedPreferences.getInstance();
    p.setString('city', city);
  }

  Future<void> fetchPrayerTimes({double? lat, double? lon}) async {
    // NOTE: For production you should use a reliable prayer-times API (eg. Diyanet) or an algorithm package.
    // Here we attempt a simple open API (AlAdhan) as a placeholder. If offline, use fixed times.
    try {
      Map<String, String> params = {};
      if (lat != null && lon != null) {
        params = {'latitude': lat.toString(), 'longitude': lon.toString(), 'method':'2'};
      } else {
        // attempt fetch by city (may not work for all APIs) - using placeholder coordinates for Gaziantep
        params = {'latitude':'37.0628','longitude':'37.3795','method':'2'};
      }
      // ALADHAN free API call (no API key required). If you prefer Diyanet, replace with Diyanet API and key.
      final uri = Uri.https('api.aladhan.com','/v1/timings', params);
      final res = await http.get(uri).timeout(Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final timings = data['data']['timings'] as Map<String,dynamic>;
        // Parse and populate prayers map with DateTime instances for today.
        DateTime today = DateTime.now();
        prayers = {};
        timings.forEach((k,v){
          // timings include values like "Fajr":"05:12 (EET)"
          final timeStr = (v as String).split(' ')[0];
          final parts = timeStr.split(':');
          if (parts.length>=2) {
            int h = int.parse(parts[0]);
            int m = int.parse(parts[1]);
            prayers[k] = DateTime(today.year, today.month, today.day, h, m);
          }
        });
      } else {
        // fallback: simple fixed times (local)
        DateTime today = DateTime.now();
        prayers = {
          'Fajr': DateTime(today.year,today.month,today.day,5,0),
          'Dhuhr': DateTime(today.year,today.month,today.day,12,30),
          'Asr': DateTime(today.year,today.month,today.day,15,45),
          'Maghrib': DateTime(today.year,today.month,today.day,18,10),
          'Isha': DateTime(today.year,today.month,today.day,19,30),
        };
      }
      scheduleNotifications();
      notifyListeners();
    } catch (e) {
      // on error, create reasonable fallback times
      DateTime today = DateTime.now();
      prayers = {
        'Fajr': DateTime(today.year,today.month,today.day,5,0),
        'Dhuhr': DateTime(today.year,today.month,today.day,12,30),
        'Asr': DateTime(today.year,today.month,today.day,15,45),
        'Maghrib': DateTime(today.year,today.month,today.day,18,10),
        'Isha': DateTime(today.year,today.month,today.day,19,30),
      };
      scheduleNotifications();
      notifyListeners();
    }
  }

  void _updateNext() {
    if (prayers.isEmpty) return;
    DateTime now = DateTime.now();
    DateTime? next;
    String label='';
    prayers.forEach((k,v){
      if (v.isAfter(now)) {
        if (next==null || v.isBefore(next)) {
          next = v;
          label = k;
        }
      }
    });
    if (next==null) {
      // if none left today, pick tomorrow's Fajr as next (simple)
      final t = prayers['Fajr'];
      if (t!=null) {
        next = t.add(Duration(days:1));
        label = 'Fajr';
      }
    }
    if (next!=null) {
      timeUntilNext = next.difference(now);
      nextPrayerLabel = label;
      notifyListeners();
    }
  }

  Future<void> scheduleNotifications() async {
    // Cancel previous
    await notifications.cancelAll();
    final androidDetails = AndroidNotificationDetails('namaz_channel', 'Namaz Bildirimleri',
      importance: Importance.max, priority: Priority.high);
    final platform = NotificationDetails(android: androidDetails);
    prayers.forEach((k,v){
      // schedule 30 min before if in future
      final before30 = v.subtract(Duration(minutes:30));
      final before2 = v.subtract(Duration(minutes:2));
      if (before30.isAfter(DateTime.now())) {
        notifications.zonedSchedule(
          before30.millisecondsSinceEpoch % 100000, // id (simple)
          'Namaz Vakti Hatırlatma',
          '$k namazına 30 dakika kaldı.',
          tz.TZDateTime.from(before30, tz.local),
          platform, androidAllowWhileIdle: true, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
      }
      if (before2.isAfter(DateTime.now())) {
        notifications.zonedSchedule(
          before2.millisecondsSinceEpoch % 100000 + 1,
          'Namaz Vakti Yaklaşıyor',
          '$k namazına 2 dakika kaldı.',
          tz.TZDateTime.from(before2, tz.local),
          platform, androidAllowWhileIdle: true, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
      }
      if (v.isAfter(DateTime.now())) {
        notifications.zonedSchedule(
          v.millisecondsSinceEpoch % 100000 + 2,
          '$k Vakti',
          '$k vakti geldi.',
          tz.TZDateTime.from(v, tz.local),
          platform, androidAllowWhileIdle: true, uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
      }
    });
  }

  Future<void> setCity(String c) async {
    city = c;
    await savePrefs();
    await fetchPrayerTimes();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

// Note: the app UI below is simplified to keep the project lightweight.
// You can expand screens and styles as required.
class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Provider.of<PrayerModel>(context);
    return Scaffold(
      appBar: AppBar(title: Text('Namaz Vakti'), actions: [
        IconButton(onPressed: () async {
          // open qibla screen
          Navigator.push(context, MaterialPageRoute(builder: (_) => QiblaPage()));
        }, icon: Icon(Icons.explore)),
        IconButton(onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => QuranPage()));
        }, icon: Icon(Icons.menu_book)),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Şehir: ${model.city}', style: TextStyle(fontSize: 16)),
            SizedBox(height:8),
            ElevatedButton(onPressed: () async {
              // choose city (simple)
              final city = await showDialog<String>(context: context, builder: (ctx){
                String temp='Gaziantep';
                return AlertDialog(
                  title: Text('Şehir seç'),
                  content: TextField(onChanged: (v)=>temp=v, decoration: InputDecoration(hintText: 'Şehir adı')),
                  actions: [TextButton(onPressed: ()=>Navigator.pop(ctx,temp), child: Text('Tamam'))],
                );
              });
              if (city!=null) Provider.of<PrayerModel>(context,listen:false).setCity(city);
            }, child: Text('Şehir Seç')),
            SizedBox(height:12),
            Card(
              child: ListTile(
                title: Text('Sonraki: ${model.nextPrayerLabel}'),
                subtitle: Text('${formatDuration(model.timeUntilNext)} kaldı'),
              ),
            ),
            SizedBox(height:12),
            Expanded(child: PrayerTable()),
          ],
        ),
      ),
    );
  }
}

class PrayerTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = Provider.of<PrayerModel>(context);
    if (model.prayers.isEmpty) return Center(child: Text('Vakitler yükleniyor...'));
    final keys = ['Fajr','Dhuhr','Asr','Maghrib','Isha'];
    return ListView.builder(itemCount: keys.length, itemBuilder: (ctx,i){
      final k = keys[i];
      final dt = model.prayers[k];
      final now = DateTime.now();
      final isNow = dt!=null && now.isAfter(dt) && now.difference(dt).inMinutes.abs()<30;
      return ListTile(
        title: Text(k),
        subtitle: Text(dt!=null?DateFormat.Hm().format(dt):'-'),
        trailing: isNow?Icon(Icons.check_circle, color: Colors.green):null,
      );
    });
  }
}

class QiblaPage extends StatefulWidget {
  @override
  _QiblaPageState createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  final _flutterQiblah = FlutterQiblah();
  @override
  void initState(){
    super.initState();
    // flutter_qiblah handles permission & compass.
  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(title: Text('Kıble Pusulası')),
      body: Center(child: Text('Kıble pusulası için flutter_qiblah paketini kullanır. Gerçek cihazda çalıştırın.')),
    );
  }
}

class QuranPage extends StatelessWidget {
  @override
  Widget build(BuildContext context){
    final sample = 'assets/quran_sample.txt';
    return Scaffold(
      appBar: AppBar(title: Text('Kur\'an-ı Kerim (örnek)')),
      body: FutureBuilder<String>(
        future: DefaultAssetBundle.of(context).loadString(sample),
        builder: (ctx,snap){
          if (!snap.hasData) return Center(child: CircularProgressIndicator());
          return Padding(padding: EdgeInsets.all(12), child: SingleChildScrollView(child: Text(snap.data!)));
        },
      ),
    );
  }
}

String formatDuration(Duration d){
  if (d.isNegative) return '0s';
  final h = d.inHours;
  final m = d.inMinutes%60;
  final s = d.inSeconds%60;
  if (h>0) return '${h}sa ${m}dk ${s}s';
  if (m>0) return '${m}dk ${s}s';
  return '${s}s';
}
