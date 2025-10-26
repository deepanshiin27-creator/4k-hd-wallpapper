import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_wallpaper_manager/flutter_wallpaper_manager.dart';
import 'package:gallery_saver/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

// 🔑 Pexels API Key
const String pexelsApiKey = "g8AtCQVEEQbRqWxRIKHYyOl53QaytsU5KGJF7TvvSMKbfVCfqMpA7jUk";

// AdMob Test IDs
const String bannerAdUnitId = "ca-app-pub-2139593035914184/4609301211";
const String interstitialAdUnitId = "ca-app-pub-2139593035914184/7830538536";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('favorites');
  await MobileAds.instance.initialize();
  runApp(WallpaperApp());
}

enum AppThemeMode { light, dark }

class WallpaperApp extends StatefulWidget {
  @override
  State<WallpaperApp> createState() => _WallpaperAppState();
}

class _WallpaperAppState extends State<WallpaperApp> {
  AppThemeMode currentMode = AppThemeMode.dark;
  bool loadingTheme = true;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString("themeMode") ?? "dark";
    setState(() {
      currentMode = mode == "light" ? AppThemeMode.light : AppThemeMode.dark;
      loadingTheme = false;
    });
  }

  Future<void> _saveThemeMode(AppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("themeMode", mode == AppThemeMode.dark ? "dark" : "light");
  }

  void toggleTheme() {
    setState(() {
      currentMode = currentMode == AppThemeMode.dark
          ? AppThemeMode.light
          : AppThemeMode.dark;
    });
    _saveThemeMode(currentMode);
  }

  @override
  Widget build(BuildContext context) {
    if (loadingTheme) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "4K & HD Wallpapers",
      theme: ThemeData(
        brightness:
            currentMode == AppThemeMode.dark ? Brightness.dark : Brightness.light,
        primarySwatch: Colors.deepPurple,
      ),
      home: SplashScreen(onComplete: (connected) {
        if (connected) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => HomePage(
                themeMode: currentMode,
                onThemeToggle: toggleTheme,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => NoInternetScreen()),
          );
        }
      }),
    );
  }
}

// ---------------- Splash Screen ----------------
class SplashScreen extends StatefulWidget {
  final Function(bool) onComplete;
  const SplashScreen({required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(Duration(seconds: 2));
    bool connected = await checkInternetConnection();
    widget.onComplete(connected);
  }

  Future<bool> checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/logo.png", height: 120),
            SizedBox(height: 16),
            Text(
              "4K & HD Wallpapers",
              style: TextStyle(
                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text("Beautiful. Fast. Free.",
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            SizedBox(height: 30),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

// ---------------- No Internet ----------------
class NoInternetScreen extends StatefulWidget {
  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> {
  bool checking = false;

  Future<void> _retryConnection() async {
    setState(() => checking = true);
    await Future.delayed(Duration(seconds: 2));
    var conn = await Connectivity().checkConnectivity();
    if (conn != ConnectivityResult.none) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => WallpaperApp(),
        ),
      );
    } else {
      setState(() => checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple.shade900,
      body: Center(
        child: checking
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text("Checking connection...",
                      style: TextStyle(color: Colors.white)),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 60),
                  SizedBox(height: 20),
                  Text(
                    "No Internet Connection",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _retryConnection,
                    icon: Icon(Icons.refresh),
                    label: Text("Try Again"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepPurple,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ---------------- Home Page with Bottom Nav ----------------
class HomePage extends StatefulWidget {
  final AppThemeMode themeMode;
  final VoidCallback onThemeToggle;

  const HomePage({required this.themeMode, required this.onThemeToggle});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  late List<Widget> pages;
  BannerAd? bannerAd;
  InterstitialAd? interstitialAd;

  @override
  void initState() {
    super.initState();
    pages = [
      WallpaperGrid(title: "Home", url: "https://api.pexels.com/v1/curated"),
      CategoriesScreen(),
      TrendingScreen(),
      FavoritesScreen(),
      SettingsScreen(
        isDark: widget.themeMode == AppThemeMode.dark,
        onThemeChange: (v) {
          widget.onThemeToggle();
          setState(() {});
        },
      ),
    ];
    _loadBannerAd();
    _loadInterstitialAd();
  }

  void _loadBannerAd() {
    bannerAd = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      listener: BannerAdListener(),
      request: AdRequest(),
    )..load();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => interstitialAd = ad,
        onAdFailedToLoad: (error) => interstitialAd = null,
      ),
    );
  }

  void _showInterstitial() {
    if (interstitialAd != null) {
      interstitialAd!.show();
      _loadInterstitialAd();
    }
  }

  @override
  void dispose() {
    bannerAd?.dispose();
    interstitialAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (bannerAd != null)
            Container(
              height: bannerAd!.size.height.toDouble(),
              width: bannerAd!.size.width.toDouble(),
              child: AdWidget(ad: bannerAd!),
            ),
          BottomNavigationBar(
            currentIndex: _selectedIndex,
            selectedItemColor: Colors.deepPurple,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            onTap: (index) {
              setState(() => _selectedIndex = index);
            },
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
              BottomNavigationBarItem(icon: Icon(Icons.category), label: "Categories"),
              BottomNavigationBarItem(icon: Icon(Icons.trending_up), label: "Trending"),
              BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Favorites"),
              BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------- Wallpaper Grid ----------------
class WallpaperGrid extends StatefulWidget {
  final String title;
  final String url;
  final bool showLoadMore;
  const WallpaperGrid(
      {super.key, required this.title, required this.url, this.showLoadMore = true});

  @override
  State<WallpaperGrid> createState() => _WallpaperGridState();
}

class _WallpaperGridState extends State<WallpaperGrid> {
  List wallpapers = [];
  int page = 1;
  bool loading = true;
  bool loadingMore = false;

  @override
  void initState() {
    super.initState();
    fetchWallpapers();
  }

  Future<void> fetchWallpapers() async {
    try {
      setState(() => loading = true);
      final res = await http.get(
        Uri.parse("${widget.url}?per_page=40&page=$page"),
        headers: {"Authorization": pexelsApiKey},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          wallpapers.addAll(data["photos"]);
          loading = false;
        });
      } else {
        throw Exception("API error");
      }
    } catch (e) {
      debugPrint("Error fetching wallpapers: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to load wallpapers")));
      setState(() => loading = false);
    }
  }

  Future<void> loadMore() async {
    if (loadingMore) return;
    setState(() => loadingMore = true);
    page++;
    await fetchWallpapers();
    setState(() => loadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: () async {
              setState(() {
                wallpapers.clear();
                page = 1;
              });
              await fetchWallpapers();
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: wallpapers.length + (widget.showLoadMore ? 1 : 0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.7,
              ),
              itemBuilder: (context, index) {
                if (widget.showLoadMore && index == wallpapers.length) {
                  return GestureDetector(
                    onTap: loadMore,
                    child: Center(
                      child: loadingMore
                          ? const CircularProgressIndicator()
                          : const Text("Show More 🔽",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  );
                }
                final photo = wallpapers[index];
                return InkWell(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              WallpaperDetail(photo: photo["src"]["large2x"]))),
                  child: Hero(
                    tag: photo["src"]["large2x"],
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: photo["src"]["portrait"],
                        fit: BoxFit.cover,
                        placeholder: (c, s) =>
                            Container(color: Colors.grey.shade900),
                        errorWidget: (c, s, e) =>
                            Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
  }
}

// ---------------- Wallpaper Detail ----------------
class WallpaperDetail extends StatefulWidget {
  final String photo;
  const WallpaperDetail({super.key, required this.photo});

  @override
  State<WallpaperDetail> createState() => _WallpaperDetailState();
}

class _WallpaperDetailState extends State<WallpaperDetail> {
  bool downloading = false;
  final Box favoritesBox = Hive.box('favorites');

  bool get isFavorite => favoritesBox.containsKey(widget.photo);

  Future<void> toggleFavorite() async {
    if (isFavorite) {
      favoritesBox.delete(widget.photo);
    } else {
      favoritesBox.put(widget.photo, widget.photo);
    }
    setState(() {});
  }

  Future<void> downloadWallpaper() async {
    try {
      if (!await Permission.photos.request().isGranted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Permission denied ❌")));
        return;
      }
      setState(() => downloading = true);
      final response = await http.get(Uri.parse(widget.photo));
      final dir = await getApplicationDocumentsDirectory();
      final file =
          File("${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg");
      await file.writeAsBytes(response.bodyBytes);

      final result = await GallerySaver.saveImage(file.path);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result == true ? "Downloaded to Gallery 📁" : "Download Failed ❌")));
    } catch (e) {
      debugPrint("Download error: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Something went wrong ❌")));
    } finally {
      setState(() => downloading = false);
    }
  }

  Future<void> setWallpaper() async {
    try {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Setting wallpaper...")));
      final response = await http.get(Uri.parse(widget.photo));
      final dir = await getApplicationDocumentsDirectory();
      final file = File("${dir.path}/temp_wallpaper.jpg");
      await file.writeAsBytes(response.bodyBytes);

      await FlutterWallpaperManager.setWallpaperFromFile(
  file.path,
  WallpaperManager.BOTH_SCREEN,
);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Wallpaper Applied ✅")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Failed to set wallpaper ❌")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Wallpaper"),
        actions: [
          IconButton(
              onPressed: toggleFavorite,
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: Colors.red))
        ],
      ),
      body: Stack(
        children: [
          Hero(
            tag: widget.photo,
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: widget.photo,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                placeholder: (c, s) =>
                    const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          if (downloading)
            const Center(
                child:
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.black54,
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton.icon(
              onPressed: downloading ? null : downloadWallpaper,
              icon: const Icon(Icons.download),
              label: const Text("Download"),
            ),
            ElevatedButton.icon(
              onPressed: downloading ? null : setWallpaper,
              icon: const Icon(Icons.wallpaper),
              label: const Text("Set Wallpaper"),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Categories ----------------
class CategoriesScreen extends StatelessWidget {
  final List<String> categories = [
    "Nature",
    "Cars",
    "Animals",
    "Abstract",
    "Technology",
    "Mountains",
    "Ocean",
    "City",
    "Minimal",
    "Flowers"
  ];

  CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Categories")),
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final cat = categories[i];
          return ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(cat),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => WallpaperGrid(
                        title: cat,
                        url:
                            "https://api.pexels.com/v1/search?query=$cat"))),
          );
        },
      ),
    );
  }
}

// ---------------- Trending ----------------
class TrendingScreen extends StatelessWidget {
  const TrendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WallpaperGrid(
      title: "Trending",
      url: "https://api.pexels.com/v1/curated?per_page=40&order_by=popular",
    );
  }
}

// ---------------- Favorites ----------------
class FavoritesScreen extends StatefulWidget {
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final Box favoritesBox = Hive.box('favorites');

  @override
  Widget build(BuildContext context) {
    final favorites = favoritesBox.values.toList();
    return favorites.isEmpty
        ? Center(
            child: Text(
              "No favorites yet 💔",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          )
        : GridView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: favorites.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.7,
            ),
            itemBuilder: (context, index) {
              final photo = favorites[index];
              return InkWell(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => WallpaperDetail(photo: photo))),
                child: Hero(
                  tag: photo,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: photo,
                      fit: BoxFit.cover,
                      placeholder: (c, s) =>
                          Container(color: Colors.grey.shade900),
                      errorWidget: (c, s, e) =>
                          Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              );
            },
          );
  }
}

// ---------------- Settings ----------------
class SettingsScreen extends StatelessWidget {
  final bool isDark;
  final Function(bool) onThemeChange;

  const SettingsScreen({required this.isDark, required this.onThemeChange});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Dark Mode"),
            value: isDark,
            onChanged: (val) => onThemeChange(val),
          ),
          ListTile(
            leading: Icon(Icons.rate_review),
            title: Text("Rate App"),
            onTap: () async {
              final url =
                  "https://play.google.com/store/apps/details?id=com.example.wallpaperapp";
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url),
                    mode: LaunchMode.externalApplication);
              }
            },
          ),
          ListTile(
            leading: Icon(Icons.share),
            title: Text("Share App"),
            onTap: () async {
              final url =
                  "https://play.google.com/store/apps/details?id=com.example.wallpaperapp";
              await launchUrl(Uri.parse("mailto:?subject=Check this App&body=$url"));
            },
          ),
        ],
      ),
    );
  }
}