// ============================================================
//  REAL-TIME PUBLIC TRANSPORT TRACKING APP — FLUTTER
//  Reduced & optimized version — under 1000 lines
// ============================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ─────────────────────────────────────────────────────────────
//  CONSTANTS
// ─────────────────────────────────────────────────────────────
const String kOrsApiKey = 'YOUR_ORS_API_KEY';

const Map<String, String> kEmoji  = {'Bus':'🚌','Auto':'🛺','Bike':'🏍️','Car':'🚗'};
const Map<String, double> kFareKm = {'Auto':12.0,'Bike':8.0,'Car':18.0};
const Map<String, double> kBase   = {'Auto':30.0,'Bike':20.0,'Car':50.0};
const Map<String, Color>  kColor  = {
  'Bus':  Color.fromARGB(255, 153, 97, 205),
  'Auto': Color(0xFFF97316),
  'Bike': Color.fromARGB(255, 91, 9, 18),
  'Car':  Color(0xFF2563EB),
};

// ─────────────────────────────────────────────────────────────
//  MODELS
// ─────────────────────────────────────────────────────────────
class BusStop  { final String name; final LatLng pos; final String time;
  const BusStop(this.name, this.pos, this.time); }

class BusRoute { final String num, name, from, to, freq, hours;
  final double fare; final Color color; final List<BusStop> stops;
  const BusRoute({required this.num,required this.name,required this.from,
    required this.to,required this.freq,required this.hours,required this.fare,
    required this.color,required this.stops}); }

class LiveBus  { final String id, routeNum, routeName;
  LatLng pos; final int pax, cap; final String nextStop; final int eta;
  LiveBus({required this.id,required this.routeNum,required this.routeName,
    required this.pos,required this.pax,required this.cap,
    required this.nextStop,required this.eta}); }

class Driver   { final String id, name, vehicle; final double rating; LatLng pos;
  Driver({required this.id,required this.name,required this.vehicle,
    required this.rating,required this.pos}); }

class FareEstimate { final double km,auto,bike,car; final int eta;
  const FareEstimate({required this.km,required this.auto,
    required this.bike,required this.car,required this.eta}); }

// ─────────────────────────────────────────────────────────────
//  BUS ROUTES DATA
// ─────────────────────────────────────────────────────────────
final List<BusRoute> kRoutes = [
  BusRoute(num:'1',name:'Dindigul - Palani',from:'Dindigul Bus Stand',to:'Palani',
    freq:'Every 20 mins',hours:'5AM-10PM',fare:35,color:const Color(0xFF16A34A),stops:[
      BusStop('Dindigul Bus Stand', LatLng(10.3673,77.9803),'6:00 AM'),
      BusStop('Dindigul Junction',  LatLng(10.3700,77.9820),'6:08 AM'),
      BusStop('Natham',             LatLng(10.4100,78.0200),'6:35 AM'),
      BusStop('Palani',             LatLng(10.4500,77.5200),'7:30 AM'),
    ]),
  BusRoute(num:'2',name:'Dindigul - Madurai',from:'Dindigul Bus Stand',to:'Madurai',
    freq:'Every 15 mins',hours:'4:30AM-11PM',fare:45,color:const Color(0xFF2563EB),stops:[
      BusStop('Dindigul Bus Stand', LatLng(10.3673,77.9803),'6:00 AM'),
      BusStop('Batlagundu',         LatLng(10.1700,77.8000),'6:55 AM'),
      BusStop('Madurai',            LatLng(9.9252, 78.1198),'7:45 AM'),
    ]),
  BusRoute(num:'3',name:'Dindigul - Kodaikanal',from:'Dindigul Bus Stand',to:'Kodaikanal',
    freq:'Every 30 mins',hours:'6AM-8PM',fare:60,color:const Color(0xFFF97316),stops:[
      BusStop('Dindigul Bus Stand', LatLng(10.3673,77.9803),'6:00 AM'),
      BusStop('Kodaikanal Road',    LatLng(10.1600,77.8100),'7:00 AM'),
      BusStop('Kodaikanal',         LatLng(10.2381,77.4892),'8:30 AM'),
    ]),
  BusRoute(num:'4',name:'City Circular',from:'Dindigul Bus Stand',to:'Dindigul Bus Stand',
    freq:'Every 10 mins',hours:'6AM-9PM',fare:10,color:const Color(0xFF8B5CF6),stops:[
      BusStop('Dindigul Bus Stand', LatLng(10.3673,77.9803),'6:00 AM'),
      BusStop('Market',             LatLng(10.3630,77.9760),'6:10 AM'),
      BusStop('Collectorate',       LatLng(10.3720,77.9850),'6:25 AM'),
    ]),
];

// ─────────────────────────────────────────────────────────────
//  ENTRY POINT
// ─────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MultiProvider(providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => BusProvider()),
    ChangeNotifierProvider(create: (_) => BookingProvider()),
    ChangeNotifierProvider(create: (_) => LocationProvider()),
  ], child: const TransportApp()));
}

class TransportApp extends StatelessWidget {
  const TransportApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'RideNow', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF16A34A)), useMaterial3: true),
    home: StreamBuilder(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting)
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return snap.hasData ? const MainNavigation() : const LoginScreen();
      },
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  MAIN NAVIGATION
// ─────────────────────────────────────────────────────────────
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override State<MainNavigation> createState() => _MainNavState();
}
class _MainNavState extends State<MainNavigation> {
  int _idx = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().fetch();
      context.read<BusProvider>().startSimulation();
    });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: [const BusScreen(), const BookScreen(), const RoutesScreen()][_idx],
    bottomNavigationBar: NavigationBar(
      selectedIndex: _idx,
      onDestinationSelected: (i) => setState(() => _idx = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.directions_bus), label: 'Live Buses'),
        NavigationDestination(icon: Icon(Icons.local_taxi),     label: 'Book Ride'),
        NavigationDestination(icon: Icon(Icons.route),          label: 'Bus Routes'),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  PROVIDERS
// ─────────────────────────────────────────────────────────────
class BusProvider extends ChangeNotifier {
  List<LiveBus> buses = [];
  BusRoute? selectedRoute;
  Timer? _timer;

  void startSimulation() {
    buses = [
      LiveBus(id:'b1',routeNum:'1',routeName:'Dindigul - Palani',  pos:LatLng(10.3700,77.9830),pax:32,cap:50,nextStop:'Dindigul Junction',eta:3),
      LiveBus(id:'b2',routeNum:'2',routeName:'Dindigul - Madurai', pos:LatLng(10.3650,77.9780),pax:45,cap:50,nextStop:'Batlagundu',eta:7),
      LiveBus(id:'b3',routeNum:'3',routeName:'Dindigul - Kodaikanal',pos:LatLng(10.3720,77.9860),pax:18,cap:40,nextStop:'Kodaikanal Road',eta:5),
      LiveBus(id:'b4',routeNum:'4',routeName:'City Circular',      pos:LatLng(10.3660,77.9810),pax:12,cap:30,nextStop:'Market',eta:2),
    ];
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      for (var b in buses) {
        b.pos = LatLng(b.pos.latitude  + 0.0002*(b.id.hashCode%3-1),
                       b.pos.longitude + 0.0002*(b.id.hashCode%2));
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void selectRoute(BusRoute? r) { selectedRoute = r; notifyListeners(); }

  @override void dispose() { _timer?.cancel(); super.dispose(); }
}

class LocationProvider extends ChangeNotifier {
  LatLng? pos; String address = 'Fetching...'; bool loading = false;
  Future<void> fetch() async {
    loading = true; notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { address = 'Enable GPS'; loading=false; notifyListeners(); return; }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        address = 'Location denied'; loading=false; notifyListeners(); return;
      }
      final p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      pos = LatLng(p.latitude, p.longitude);
      final res = await http.get(Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${p.latitude}&lon=${p.longitude}&format=json'),
          headers: {'User-Agent':'RideNowApp/1.0'});
      final d = jsonDecode(res.body);
      final parts = (d['display_name'] as String).split(',');
      address = parts.length > 2 ? '${parts[0].trim()}, ${parts[1].trim()}' : d['display_name'];
    } catch (_) { address = 'Location unavailable'; }
    loading = false; notifyListeners();
  }
}

enum BookStatus { idle, searching, confirmed }
class BookingProvider extends ChangeNotifier {
  String vehicle = 'Auto';
  LatLng? dest; String destAddr = '';
  FareEstimate? fare; BookStatus status = BookStatus.idle;
  Driver? driver; List<LatLng> route = []; bool fareLoading = false;

  void selectVehicle(String v) { vehicle = v; notifyListeners(); }
  void setDest(LatLng p, String a) { dest = p; destAddr = a; notifyListeners(); }

  Future<void> calcFare(LatLng o, LatLng d) async {
    fareLoading = true; route = []; fare = null; notifyListeners();
    try {
      final res = await http.get(Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-car?api_key=$kOrsApiKey&start=${o.longitude},${o.latitude}&end=${d.longitude},${d.latitude}'));
      final j = jsonDecode(res.body);
      final seg = j['features'][0]['properties']['segments'][0];
      final km  = (seg['distance'] as num).toDouble() / 1000;
      final min = ((seg['duration'] as num).toDouble() / 60).round();
      route = (j['features'][0]['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
      fare = FareEstimate(km:km, auto:kBase['Auto']!+km*kFareKm['Auto']!,
          bike:kBase['Bike']!+km*kFareKm['Bike']!, car:kBase['Car']!+km*kFareKm['Car']!, eta:min);
    } catch (_) {
      final km = const Distance().as(LengthUnit.Kilometer, o, d);
      fare = FareEstimate(km:km, auto:kBase['Auto']!+km*kFareKm['Auto']!,
          bike:kBase['Bike']!+km*kFareKm['Bike']!, car:kBase['Car']!+km*kFareKm['Car']!, eta:(km*3).round());
      route = [o, d];
    }
    fareLoading = false; notifyListeners();
  }

  Future<void> confirmBooking(LatLng origin) async {
    status = BookStatus.searching; notifyListeners();
    await Future.delayed(const Duration(seconds: 3));
    driver = Driver(id:'d1', name:'Rajan Kumar', vehicle:vehicle, rating:4.8,
        pos:LatLng(origin.latitude+0.003, origin.longitude+0.002));
    status = BookStatus.confirmed; notifyListeners();
    try {
      await FirebaseFirestore.instance.collection('bookings').add({
        'vehicle': vehicle, 'destAddr': destAddr,
        'fare': _curFare(), 'status': 'confirmed',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  double _curFare() { if (fare==null) return 0;
    return vehicle=='Auto'?fare!.auto:vehicle=='Bike'?fare!.bike:fare!.car; }

  void cancel() { status = BookStatus.idle; driver = null; notifyListeners(); }
}

class AuthProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _google = GoogleSignIn();
  bool loading = false;

  Future<void> googleSignIn({required VoidCallback onSuccess, required Function(String) onError}) async {
    loading = true; notifyListeners();
    try {
      final g = await _google.signIn();
      if (g == null) { loading=false; notifyListeners(); return; }
      final ga = await g.authentication;
      final cred = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(accessToken: ga.accessToken, idToken: ga.idToken));
      if (cred.additionalUserInfo?.isNewUser == true) {
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'name': cred.user!.displayName??'', 'email': cred.user!.email??'',
          'createdAt': FieldValue.serverTimestamp(), 'totalRides': 0,
        });
      }
      loading=false; notifyListeners(); onSuccess();
    } catch (e) { loading=false; notifyListeners(); onError(e.toString()); }
  }

  Future<void> emailRegister({required String name, required String email,
      required String password, required VoidCallback onSuccess, required Function(String) onError}) async {
    loading=true; notifyListeners();
    try {
      final c = await _auth.createUserWithEmailAndPassword(email:email, password:password);
      await c.user!.updateDisplayName(name);
      await FirebaseFirestore.instance.collection('users').doc(c.user!.uid).set({
        'name':name,'email':email,'createdAt':FieldValue.serverTimestamp(),'totalRides':0});
      loading=false; notifyListeners(); onSuccess();
    } on FirebaseAuthException catch (e) {
      loading=false;
      onError(e.code=='email-already-in-use'?'Email already registered':e.code=='weak-password'?'Min 6 chars':e.message??'Failed');
      notifyListeners();
    }
  }

  Future<void> emailLogin({required String email, required String password,
      required VoidCallback onSuccess, required Function(String) onError}) async {
    loading=true; notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(email:email, password:password);
      loading=false; notifyListeners(); onSuccess();
    } on FirebaseAuthException catch (e) {
      loading=false;
      onError(e.code=='user-not-found'?'No account found':e.code=='wrong-password'?'Wrong password':e.message??'Failed');
      notifyListeners();
    }
  }

  Future<void> signOut() async { await _google.signOut(); await _auth.signOut(); notifyListeners(); }
}

// ─────────────────────────────────────────────────────────────
//  SCREEN 1: LIVE BUS TRACKING
// ─────────────────────────────────────────────────────────────
class BusScreen extends StatefulWidget {
  const BusScreen({super.key});
  @override State<BusScreen> createState() => _BusScreenState();
}
class _BusScreenState extends State<BusScreen> {
  final _map = MapController();
  LiveBus? _sel;

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationProvider>();
    final bp  = context.watch<BusProvider>();
    final ctr = loc.pos ?? const LatLng(10.3673, 77.9803);
    return Scaffold(
      body: Stack(children: [
        FlutterMap(mapController: _map,
          options: MapOptions(initialCenter: ctr, initialZoom: 14),
          children: [
            TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.ridenow'),
            MarkerLayer(markers: [
              if (loc.pos != null)
                Marker(point: loc.pos!, width:40, height:40,
                  child: Container(decoration: BoxDecoration(color:Colors.blue,
                      shape:BoxShape.circle, border:Border.all(color:Colors.white,width:3)))),
              ...bp.buses.map((b) {
                final r = kRoutes.firstWhere((x)=>x.num==b.routeNum, orElse:()=>kRoutes.first);
                final sel = _sel?.id == b.id;
                return Marker(point:b.pos, width:60, height:60,
                  child: GestureDetector(onTap:()=>setState(()=>_sel=b),
                    child: Container(padding:const EdgeInsets.all(4),
                      decoration: BoxDecoration(color:sel?r.color:r.color.withOpacity(0.85),
                          borderRadius:BorderRadius.circular(10),
                          border:sel?Border.all(color:Colors.white,width:2):null,
                          boxShadow:[BoxShadow(color:r.color.withOpacity(0.5),blurRadius:8)]),
                      child: Column(mainAxisAlignment:MainAxisAlignment.center,
                        children: [const Text('🚌',style:TextStyle(fontSize:18)),
                          Text(b.routeNum,style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.bold))]))));
              }),
            ]),
          ],
        ),

        // Top bar
        SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:12),
            decoration:BoxDecoration(color:Colors.white, borderRadius:BorderRadius.circular(12),
                boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.1),blurRadius:8)]),
            child: Row(children: [
              const Icon(Icons.directions_bus, color:Color(0xFF16A34A)),
              const SizedBox(width:10),
              const Expanded(child:Text('Live Bus Tracking',style:TextStyle(fontWeight:FontWeight.w600,fontSize:16))),
              Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),
                decoration:BoxDecoration(color:Colors.green[50],borderRadius:BorderRadius.circular(20)),
                child:Row(children:[Container(width:6,height:6,decoration:const BoxDecoration(color:Colors.green,shape:BoxShape.circle)),
                  const SizedBox(width:4),Text('${bp.buses.length} live',style:const TextStyle(color:Colors.green,fontSize:12))])),
            ])),
          const SizedBox(height:8),
          SingleChildScrollView(scrollDirection:Axis.horizontal,
            child:Row(children:[
              _chip('All',Colors.grey, bp.selectedRoute==null, ()=>bp.selectRoute(null)),
              ...kRoutes.map((r)=>_chip('Route ${r.num}',r.color,bp.selectedRoute?.num==r.num,()=>bp.selectRoute(r))),
            ])),
        ]))),

        // Bottom
        if (_sel != null)
          Align(alignment:Alignment.bottomCenter, child:_busPanel(_sel!,()=>setState(()=>_sel=null)))
        else
          Align(alignment:Alignment.bottomCenter, child:_nearbyList(bp.buses,(b){
            setState(()=>_sel=b); _map.move(b.pos,15);})),
      ]),
    );
  }

  Widget _chip(String label, Color color, bool selected, VoidCallback onTap) =>
    GestureDetector(onTap:onTap,
      child:Container(margin:const EdgeInsets.only(right:8),
        padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),
        decoration:BoxDecoration(color:selected?color:Colors.white,
            borderRadius:BorderRadius.circular(20),
            border:Border.all(color:selected?color:Colors.grey[300]!)),
        child:Text(label,style:TextStyle(color:selected?Colors.white:Colors.black87,fontSize:12,fontWeight:FontWeight.w500))));

  Widget _busPanel(LiveBus bus, VoidCallback onClose) {
    final r = kRoutes.firstWhere((x)=>x.num==bus.routeNum, orElse:()=>kRoutes.first);
    final pct = (bus.pax/bus.cap*100).round();
    return Container(margin:const EdgeInsets.all(12), padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(16),
          boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.15),blurRadius:12)]),
      child:Column(mainAxisSize:MainAxisSize.min, children:[
        Row(children:[
          Container(padding:const EdgeInsets.all(10),
            decoration:BoxDecoration(color:r.color.withOpacity(0.1),borderRadius:BorderRadius.circular(10)),
            child:const Text('🚌',style:TextStyle(fontSize:24))),
          const SizedBox(width:12),
          Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:2),
              decoration:BoxDecoration(color:r.color,borderRadius:BorderRadius.circular(6)),
              child:Text('Route ${bus.routeNum}',style:const TextStyle(color:Colors.white,fontSize:11,fontWeight:FontWeight.bold))),
              const SizedBox(width:8),
              Container(width:8,height:8,decoration:const BoxDecoration(color:Colors.green,shape:BoxShape.circle)),
              const SizedBox(width:4),const Text('Live',style:TextStyle(color:Colors.green,fontSize:12))]),
            const SizedBox(height:4),
            Text(bus.routeName,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:15))
          ])),
          IconButton(onPressed:onClose,icon:const Icon(Icons.close),iconSize:20),
        ]),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child:Column(children:[const Text('📍',style:TextStyle(fontSize:20)),const SizedBox(height:4),
            Text(bus.nextStop,style:const TextStyle(fontWeight:FontWeight.w600,fontSize:12)),
            const Text('Next Stop',style:TextStyle(color:Colors.grey,fontSize:11))])),
          Expanded(child:Column(children:[const Text('⏱️',style:TextStyle(fontSize:20)),const SizedBox(height:4),
            Text('${bus.eta} mins',style:const TextStyle(fontWeight:FontWeight.w600,fontSize:13)),
            const Text('ETA',style:TextStyle(color:Colors.grey,fontSize:11))])),
          Expanded(child:Column(children:[const Text('🪑',style:TextStyle(fontSize:20)),const SizedBox(height:4),
            Text('$pct%',style:const TextStyle(fontWeight:FontWeight.w600,fontSize:13)),
            const Text('Occupancy',style:TextStyle(color:Colors.grey,fontSize:11))])),
        ]),
        const SizedBox(height:12),
        ClipRRect(borderRadius:BorderRadius.circular(4),
          child:LinearProgressIndicator(value:bus.pax/bus.cap, backgroundColor:Colors.grey[200],
            color:pct>80?Colors.red:pct>50?Colors.orange:Colors.green, minHeight:8)),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child:OutlinedButton.icon(onPressed:(){},icon:const Icon(Icons.route,size:16),
            label:const Text('View Route'),
            style:OutlinedButton.styleFrom(foregroundColor:r.color,side:BorderSide(color:r.color)))),
          const SizedBox(width:8),
          Expanded(child:ElevatedButton.icon(onPressed:(){},icon:const Icon(Icons.notifications,size:16),
            label:const Text('Track This'),
            style:ElevatedButton.styleFrom(backgroundColor:r.color,foregroundColor:Colors.white))),
        ]),
      ]));
  }

  Widget _nearbyList(List<LiveBus> buses, Function(LiveBus) onTap) =>
    Container(height:180,
      decoration:const BoxDecoration(color:Colors.white,
          borderRadius:BorderRadius.vertical(top:Radius.circular(20)),
          boxShadow:[BoxShadow(color:Colors.black12,blurRadius:10)]),
      child:Column(children:[
        Container(width:40,height:4,margin:const EdgeInsets.only(top:10),
            decoration:BoxDecoration(color:Colors.grey[300],borderRadius:BorderRadius.circular(2))),
        const Padding(padding:EdgeInsets.symmetric(horizontal:16,vertical:8),
          child:Row(children:[Text('Nearby Buses',style:TextStyle(fontWeight:FontWeight.w600,fontSize:15)),
            Spacer(),Text('Tap to track',style:TextStyle(color:Colors.grey,fontSize:12))])),
        Expanded(child:ListView.builder(scrollDirection:Axis.horizontal,
          padding:const EdgeInsets.symmetric(horizontal:12), itemCount:buses.length,
          itemBuilder:(_,i){
            final b=buses[i];
            final r=kRoutes.firstWhere((x)=>x.num==b.routeNum,orElse:()=>kRoutes.first);
            return GestureDetector(onTap:()=>onTap(b),
              child:Container(width:150,margin:const EdgeInsets.only(right:10,bottom:12),
                padding:const EdgeInsets.all(10),
                decoration:BoxDecoration(color:r.color.withOpacity(0.08),
                    borderRadius:BorderRadius.circular(12),
                    border:Border.all(color:r.color.withOpacity(0.3))),
                child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Row(children:[const Text('🚌',style:TextStyle(fontSize:18)),const SizedBox(width:6),
                    Container(padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),
                      decoration:BoxDecoration(color:r.color,borderRadius:BorderRadius.circular(4)),
                      child:Text('Route ${b.routeNum}',style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.bold)))]),
                  const SizedBox(height:6),
                  Text(b.routeName,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w600),maxLines:1,overflow:TextOverflow.ellipsis),
                  const SizedBox(height:4),
                  Text('⏱ ${b.eta} mins',style:TextStyle(fontSize:11,color:r.color)),
                ])));
          })),
      ]));
}

// ─────────────────────────────────────────────────────────────
//  SCREEN 2: BOOK RIDE
// ─────────────────────────────────────────────────────────────
class BookScreen extends StatefulWidget {
  const BookScreen({super.key});
  @override State<BookScreen> createState() => _BookScreenState();
}
class _BookScreenState extends State<BookScreen> {
  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationProvider>();
    final bk  = context.watch<BookingProvider>();
    final ctr = loc.pos ?? const LatLng(10.3673,77.9803);
    return Scaffold(
      body: Stack(children: [
        FlutterMap(options:MapOptions(initialCenter:ctr,initialZoom:14),
          children:[
            TileLayer(urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:'com.example.ridenow'),
            if (bk.route.isNotEmpty)
              PolylineLayer(polylines:[Polyline(points:bk.route,strokeWidth:4,color:const Color(0xFF2563EB))]),
            MarkerLayer(markers:[
              if (loc.pos!=null) Marker(point:loc.pos!,width:40,height:40,
                child:Container(decoration:BoxDecoration(color:Colors.blue,shape:BoxShape.circle,
                    border:Border.all(color:Colors.white,width:3)))),
              if (bk.dest!=null) Marker(point:bk.dest!,width:40,height:50,
                child:const Icon(Icons.location_on,color:Colors.red,size:40)),
              if (bk.driver!=null) Marker(point:bk.driver!.pos,width:50,height:50,
                child:Container(padding:const EdgeInsets.all(6),
                  decoration:BoxDecoration(color:kColor[bk.driver!.vehicle],borderRadius:BorderRadius.circular(8),
                      boxShadow:[BoxShadow(color:(kColor[bk.driver!.vehicle]??Colors.blue).withOpacity(0.4),blurRadius:6)]),
                  child:Text(kEmoji[bk.driver!.vehicle]??'🚗',style:const TextStyle(fontSize:16)))),
            ]),
          ]),
        SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:Column(children:[
          _locBar(loc.address, true, loc.loading),
          const SizedBox(height:8),
          GestureDetector(onTap:()=>Navigator.push(context,MaterialPageRoute(
            builder:(_)=>MultiProvider(providers:[
              ChangeNotifierProvider.value(value:context.read<BookingProvider>()),
              ChangeNotifierProvider.value(value:context.read<LocationProvider>()),
            ],child:const SearchScreen()))),
            child:_locBar(bk.destAddr.isEmpty?'Where to?':bk.destAddr, false, false)),
        ]))),
        const Align(alignment:Alignment.bottomCenter,child:BookSheet()),
      ]),
    );
  }

  Widget _locBar(String text, bool isLoc, bool loading) => Container(
    padding:const EdgeInsets.symmetric(horizontal:16,vertical:14),
    decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12),
        boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.08),blurRadius:8,offset:const Offset(0,2))]),
    child:Row(children:[
      Icon(isLoc?Icons.my_location:Icons.location_on, color:isLoc?Colors.blue:Colors.red,size:20),
      const SizedBox(width:12),
      Expanded(child:Text(text,style:TextStyle(color:text.contains('?')||text=='Fetching...'?Colors.grey[500]:Colors.black87,fontSize:15),overflow:TextOverflow.ellipsis)),
      if (loading) const SizedBox(width:16,height:16,child:CircularProgressIndicator(strokeWidth:2)),
    ]));
}

// ─────────────────────────────────────────────────────────────
//  BOOK SHEET
// ─────────────────────────────────────────────────────────────
class BookSheet extends StatelessWidget {
  const BookSheet({super.key});
  @override
  Widget build(BuildContext context) {
    final bk  = context.watch<BookingProvider>();
    final loc = context.watch<LocationProvider>();
    double fareFor(String v) => v=='Auto'?bk.fare!.auto:v=='Bike'?bk.fare!.bike:bk.fare!.car;

    return Container(
      decoration:const BoxDecoration(color:Colors.white,
          borderRadius:BorderRadius.vertical(top:Radius.circular(24)),
          boxShadow:[BoxShadow(color:Colors.black12,blurRadius:12)]),
      padding:const EdgeInsets.fromLTRB(20,16,20,32),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Center(child:Container(width:40,height:4,
            decoration:BoxDecoration(color:Colors.grey[300],borderRadius:BorderRadius.circular(2)))),
        const SizedBox(height:16),

        if (bk.status==BookStatus.idle)...[
          const Text('Choose your ride',style:TextStyle(fontSize:18,fontWeight:FontWeight.w600)),
          const SizedBox(height:16),
          Row(children:['Auto','Bike','Car'].map((v){
            final sel = bk.vehicle==v;
            final c   = kColor[v]??Colors.blue;
            return Expanded(child:GestureDetector(onTap:()=>bk.selectVehicle(v),
              child:AnimatedContainer(duration:const Duration(milliseconds:200),
                margin:const EdgeInsets.symmetric(horizontal:4),
                padding:const EdgeInsets.symmetric(vertical:14),
                decoration:BoxDecoration(color:sel?c:Colors.grey[100],borderRadius:BorderRadius.circular(12)),
                child:Column(children:[Text(kEmoji[v]??'🚗',style:const TextStyle(fontSize:28)),
                  const SizedBox(height:6),
                  Text(v,style:TextStyle(fontSize:13,fontWeight:FontWeight.w500,
                      color:sel?Colors.white:Colors.black87))]))));
          }).toList()),
          const SizedBox(height:16),
          if (bk.fareLoading) const Center(child:CircularProgressIndicator())
          else if (bk.fare!=null)...[
            Container(padding:const EdgeInsets.all(14),
              decoration:BoxDecoration(color:Colors.blue[50],borderRadius:BorderRadius.circular(12)),
              child:Column(children:[
                Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                  Text('${bk.fare!.km.toStringAsFixed(1)} km  ·  ~${bk.fare!.eta} min',
                      style:const TextStyle(fontSize:13,color:Colors.black54)),
                  Text('₹${fareFor(bk.vehicle).toStringAsFixed(0)}',
                      style:const TextStyle(fontSize:24,fontWeight:FontWeight.w700,color:Color(0xFF2563EB))),
                ]),
                const Divider(height:16),
                Row(mainAxisAlignment:MainAxisAlignment.spaceAround,
                  children:['Auto','Bike','Car'].map((v){
                    final sel=bk.vehicle==v; final c=kColor[v]??Colors.blue;
                    return Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:6),
                      decoration:BoxDecoration(color:sel?c:Colors.white,borderRadius:BorderRadius.circular(20),
                          border:Border.all(color:sel?c:Colors.grey[300]!)),
                      child:Text('${kEmoji[v]}  ₹${fareFor(v).toStringAsFixed(0)}',
                          style:TextStyle(fontSize:12,fontWeight:FontWeight.w500,
                              color:sel?Colors.white:Colors.black87)));
                  }).toList()),
              ])),
            const SizedBox(height:16),
          ],
          SizedBox(width:double.infinity,height:52,
            child:ElevatedButton(
              onPressed:bk.dest!=null&&loc.pos!=null?()=>bk.confirmBooking(loc.pos!):null,
              style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF2563EB),
                  foregroundColor:Colors.white,disabledBackgroundColor:Colors.grey[300],
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),
              child:Text(bk.dest==null?'Select a destination first'
                  :'Book ${bk.vehicle}  ·  ₹${bk.fare!=null?fareFor(bk.vehicle).toStringAsFixed(0):"..."}')))
        ],

        if (bk.status==BookStatus.searching)
          const Padding(padding:EdgeInsets.symmetric(vertical:24),
            child:Column(children:[CircularProgressIndicator(),SizedBox(height:16),
              Text('Finding your driver...',style:TextStyle(fontSize:16,fontWeight:FontWeight.w600))])),

        if (bk.status==BookStatus.confirmed&&bk.driver!=null)...[
          Container(padding:const EdgeInsets.all(14),
            decoration:BoxDecoration(color:Colors.green[50],borderRadius:BorderRadius.circular(12)),
            child:const Row(children:[Icon(Icons.check_circle,color:Colors.green,size:20),
              SizedBox(width:8),Text('Driver is on the way!',style:TextStyle(color:Colors.green,fontWeight:FontWeight.w600))])),
          const SizedBox(height:14),
          Row(children:[
            CircleAvatar(radius:28,backgroundColor:Colors.blue[100],
                child:Text(kEmoji[bk.driver!.vehicle]??'🚗',style:const TextStyle(fontSize:26))),
            const SizedBox(width:14),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(bk.driver!.name,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w600)),
              Row(children:[const Icon(Icons.star,size:14,color:Colors.amber),
                Text(' ${bk.driver!.rating}  ·  ${bk.driver!.vehicle}',
                    style:const TextStyle(fontSize:13,color:Colors.grey))]),
            ])),
            IconButton(onPressed:(){},icon:const Icon(Icons.call,color:Color(0xFF2563EB))),
          ]),
          const SizedBox(height:14),
          SizedBox(width:double.infinity,
            child:OutlinedButton(onPressed:bk.cancel,
              style:OutlinedButton.styleFrom(foregroundColor:Colors.red,side:const BorderSide(color:Colors.red),
                  shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12)),
                  padding:const EdgeInsets.symmetric(vertical:14)),
              child:const Text('Cancel Ride'))),
        ],
      ]));
  }
}

// ─────────────────────────────────────────────────────────────
//  SCREEN 3: BUS ROUTES
// ─────────────────────────────────────────────────────────────
class RoutesScreen extends StatelessWidget {
  const RoutesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar:AppBar(title:const Text('Bus Routes'),backgroundColor:const Color(0xFF16A34A),foregroundColor:Colors.white),
    body:ListView.builder(padding:const EdgeInsets.all(16),itemCount:kRoutes.length,
      itemBuilder:(_,i){
        final r=kRoutes[i];
        return Card(margin:const EdgeInsets.only(bottom:16),elevation:2,
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),
          child:ExpansionTile(
            tilePadding:const EdgeInsets.all(16),
            childrenPadding:const EdgeInsets.fromLTRB(16,0,16,16),
            leading:Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:6),
              decoration:BoxDecoration(color:r.color,borderRadius:BorderRadius.circular(8)),
              child:Text('Route ${r.num}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold,fontSize:13))),
            title:Text(r.name,style:const TextStyle(fontWeight:FontWeight.w600)),
            subtitle:Padding(padding:const EdgeInsets.only(top:8),
              child:Row(children:[
                Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
                  decoration:BoxDecoration(color:Colors.grey[100],borderRadius:BorderRadius.circular(6)),
                  child:Text('🕒 ${r.freq}',style:const TextStyle(fontSize:11))),
                const SizedBox(width:6),
                Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:3),
                  decoration:BoxDecoration(color:Colors.grey[100],borderRadius:BorderRadius.circular(6)),
                  child:Text('💰 ₹${r.fare.toStringAsFixed(0)}',style:const TextStyle(fontSize:11))),
              ])),
            children:[
              ...r.stops.asMap().entries.map((e){
                final idx=e.key; final s=e.value;
                final isEnd=idx==0||idx==r.stops.length-1;
                return Padding(padding:const EdgeInsets.symmetric(vertical:4),
                  child:Row(children:[
                    SizedBox(width:24,child:Column(children:[
                      if (idx>0) Container(width:2,height:20,color:r.color),
                      Container(width:14,height:14,decoration:BoxDecoration(
                          color:isEnd?r.color:Colors.white,shape:BoxShape.circle,
                          border:Border.all(color:r.color,width:2))),
                      if (idx<r.stops.length-1) Container(width:2,height:20,color:r.color),
                    ])),
                    const SizedBox(width:12),
                    Expanded(child:Container(padding:const EdgeInsets.all(10),
                      decoration:BoxDecoration(color:isEnd?r.color.withOpacity(0.1):Colors.grey[50],
                          borderRadius:BorderRadius.circular(8),
                          border:isEnd?Border.all(color:r.color.withOpacity(0.3)):null),
                      child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
                        Text(s.name,style:TextStyle(fontWeight:isEnd?FontWeight.w600:FontWeight.normal,fontSize:13)),
                        Text(s.time,style:TextStyle(color:r.color,fontSize:12,fontWeight:FontWeight.w500)),
                      ]))),
                  ]));
              }),
            ],
          ));
      }));
}

// ─────────────────────────────────────────────────────────────
//  DESTINATION SEARCH
// ─────────────────────────────────────────────────────────────
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override State<SearchScreen> createState() => _SearchState();
}
class _SearchState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  List<Map<String,dynamic>> _res = []; bool _load = false; Timer? _deb;
  @override void dispose() { _ctrl.dispose(); _deb?.cancel(); super.dispose(); }

  Future<void> _search(String q) async {
    if (q.length<3) { setState(()=>_res=[]); return; }
    setState(()=>_load=true);
    try {
      final loc = context.read<LocationProvider>().pos;
      String vb = loc!=null?'&viewbox=${loc.longitude-1},${loc.latitude+1},${loc.longitude+1},${loc.latitude-1}&bounded=0':'';
      final res = await http.get(Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(q)}&format=json&limit=6&countrycodes=in$vb'),
          headers:{'User-Agent':'RideNowApp/1.0'});
      final d = jsonDecode(res.body) as List;
      setState(()=>_res=d.map((x)=>{'displayName':x['display_name'],
        'shortName':(x['display_name'] as String).split(',').take(2).join(','),
        'lat':double.parse(x['lat']),'lng':double.parse(x['lon'])}).toList());
    } catch (_) {}
    setState(()=>_load=false);
  }

  void _pick(Map<String,dynamic> p) {
    final bk=context.read<BookingProvider>(); final loc=context.read<LocationProvider>();
    final d=LatLng(p['lat'],p['lng']);
    bk.setDest(d,p['shortName']);
    if (loc.pos!=null) bk.calcFare(loc.pos!,d);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:Colors.white,
    appBar:AppBar(title:const Text('Where to?'),backgroundColor:Colors.white,foregroundColor:Colors.black87,elevation:0),
    body:Column(children:[
      Padding(padding:const EdgeInsets.fromLTRB(16,8,16,0),
        child:TextField(controller:_ctrl,autofocus:true,
          decoration:InputDecoration(hintText:'Search any place in India',
            prefixIcon:const Icon(Icons.search,color:Colors.grey),
            suffixIcon:_load?const Padding(padding:EdgeInsets.all(14),
                child:SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2))):null,
            border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:Colors.grey[300]!)),
            enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:Colors.grey[300]!)),
            focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:Color(0xFF2563EB),width:2)),
            filled:true,fillColor:Colors.grey[50]),
          onChanged:(v){_deb?.cancel();_deb=Timer(const Duration(milliseconds:500),()=>_search(v));})),
      const SizedBox(height:8),
      Expanded(child:_res.isEmpty&&!_load
        ?Center(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            Icon(Icons.search,size:60,color:Colors.grey[300]),const SizedBox(height:12),
            Text('Type to search for a destination',style:TextStyle(color:Colors.grey[400]))]))
        :ListView.builder(itemCount:_res.length,itemBuilder:(_,i){
            final p=_res[i];
            return ListTile(
              leading:Container(padding:const EdgeInsets.all(8),
                  decoration:BoxDecoration(color:Colors.grey[100],shape:BoxShape.circle),
                  child:const Icon(Icons.location_on,color:Colors.red,size:20)),
              title:Text(p['shortName'],style:const TextStyle(fontWeight:FontWeight.w500,fontSize:14)),
              subtitle:Text(p['displayName'],maxLines:1,overflow:TextOverflow.ellipsis,
                  style:const TextStyle(fontSize:11,color:Colors.grey)),
              onTap:()=>_pick(p));
          })),
    ]));
}

// ─────────────────────────────────────────────────────────────
//  LOGIN SCREEN
// ─────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginState();
}
class _LoginState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _le=TextEditingController(),_lp=TextEditingController();
  final _rn=TextEditingController(),_re=TextEditingController(),_rp=TextEditingController();
  bool _ol=true,_or=true;
  @override void initState() { super.initState(); _tab=TabController(length:2,vsync:this); }
  @override void dispose() { _tab.dispose();_le.dispose();_lp.dispose();_rn.dispose();_re.dispose();_rp.dispose(); super.dispose(); }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m),backgroundColor:Colors.red));
  void _ok(String m)  => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m),backgroundColor:Colors.green));

  Widget _field(TextEditingController c,String hint,IconData icon,{bool obs=false,VoidCallback? toggle,TextInputType? kb})=>
    TextField(controller:c,obscureText:obs,keyboardType:kb,
      decoration:InputDecoration(hintText:hint,
        prefixIcon:Icon(icon,color:Colors.grey,size:20),
        suffixIcon:toggle!=null?IconButton(onPressed:toggle,
          icon:Icon(obs?Icons.visibility_off:Icons.visibility,color:Colors.grey,size:20)):null,
        border:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:Colors.grey[300]!)),
        enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:BorderSide(color:Colors.grey[300]!)),
        focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(12),borderSide:const BorderSide(color:Color(0xFF16A34A),width:2)),
        filled:true,fillColor:Colors.grey[50],
        contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:14)));

  Widget _btn(String label,VoidCallback? onTap,bool loading)=>SizedBox(width:double.infinity,height:50,
    child:ElevatedButton(onPressed:onTap,
      style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF16A34A),foregroundColor:Colors.white,
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
      child:loading?const SizedBox(width:20,height:20,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))
          :Text(label,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w600))));

  @override
  Widget build(BuildContext context) {
    final auth=context.watch<AuthProvider>();
    return Scaffold(body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(children:[
      const SizedBox(height:30),
      Container(width:80,height:80,decoration:BoxDecoration(color:const Color(0xFF16A34A),borderRadius:BorderRadius.circular(20)),
          child:const Center(child:Text('🚌',style:TextStyle(fontSize:40)))),
      const SizedBox(height:14),
      const Text('RideNow',style:TextStyle(fontSize:30,fontWeight:FontWeight.w800,color:Color(0xFF16A34A))),
      const Text('Track buses · Book rides',style:TextStyle(color:Colors.grey)),
      const SizedBox(height:32),
      SizedBox(width:double.infinity,height:52,
        child:OutlinedButton.icon(
          onPressed:auth.loading?null:()=>context.read<AuthProvider>().googleSignIn(onSuccess:(){},onError:_err),
          icon:const Text('G',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold,color:Colors.red)),
          label:const Text('Continue with Google',style:TextStyle(fontSize:15,fontWeight:FontWeight.w500)),
          style:OutlinedButton.styleFrom(foregroundColor:Colors.black87,
              side:BorderSide(color:Colors.grey[300]!),
              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))))),
      const SizedBox(height:20),
      Row(children:[Expanded(child:Divider(color:Colors.grey[300])),
        Padding(padding:const EdgeInsets.symmetric(horizontal:12),
            child:Text('or use email',style:TextStyle(color:Colors.grey[500],fontSize:13))),
        Expanded(child:Divider(color:Colors.grey[300]))]),
      const SizedBox(height:20),
      Container(decoration:BoxDecoration(color:Colors.grey[100],borderRadius:BorderRadius.circular(12)),
        child:TabBar(controller:_tab,
          indicator:BoxDecoration(color:const Color(0xFF16A34A),borderRadius:BorderRadius.circular(10)),
          labelColor:Colors.white,unselectedLabelColor:Colors.black54,dividerColor:Colors.transparent,
          tabs:const [Tab(text:'Login'),Tab(text:'Register')])),
      const SizedBox(height:20),
      SizedBox(height:290,child:TabBarView(controller:_tab,children:[
        // Login
        Column(children:[
          _field(_le,'Email',Icons.email_outlined,kb:TextInputType.emailAddress),
          const SizedBox(height:12),
          _field(_lp,'Password',Icons.lock_outline,obs:_ol,toggle:()=>setState(()=>_ol=!_ol)),
          const SizedBox(height:20),
          _btn('Login',auth.loading?null:(){
            if (_le.text.trim().isEmpty||_lp.text.trim().isEmpty){_err('Fill all fields');return;}
            context.read<AuthProvider>().emailLogin(email:_le.text.trim(),password:_lp.text.trim(),onSuccess:(){},onError:_err);
          },auth.loading),
        ]),
        // Register
        Column(children:[
          _field(_rn,'Full name',Icons.person_outline),
          const SizedBox(height:10),
          _field(_re,'Email',Icons.email_outlined,kb:TextInputType.emailAddress),
          const SizedBox(height:10),
          _field(_rp,'Password (min 6)',Icons.lock_outline,obs:_or,toggle:()=>setState(()=>_or=!_or)),
          const SizedBox(height:16),
          _btn('Create Account',auth.loading?null:(){
            if (_rn.text.trim().isEmpty||_re.text.trim().isEmpty||_rp.text.trim().isEmpty){_err('Fill all fields');return;}
            context.read<AuthProvider>().emailRegister(name:_rn.text.trim(),email:_re.text.trim(),
                password:_rp.text.trim(),onSuccess:()=>_ok('Account created!'),onError:_err);
          },auth.loading),
        ]),
      ])),
    ]))));
  }
}