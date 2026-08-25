import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'blocs/diet_bloc.dart';
import 'core/theme.dart';
import 'ui/screens/diet_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize HydratedBloc Storage
  try {
    final storage = await HydratedStorage.build(
      storageDirectory: kIsWeb
          ? HydratedStorageDirectory.web
          : HydratedStorageDirectory((await getApplicationDocumentsDirectory()).path),
    );
    HydratedBloc.storage = storage;
  } catch (e) {
    debugPrint('HydratedBloc storage initialization failed: $e');
  }

  // 2. Initialize Supabase (Handles offline/missing configs gracefully)
  try {
    await Supabase.initialize(
      url: const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://your-placeholder-url.supabase.co',
      ),
      publishableKey: const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'your-placeholder-anon-key',
      ),
    );
  } catch (e) {
    debugPrint('Supabase initialization failed: $e. Running in local-only mode.');
  }

  runApp(const PlateMateApp());
}

class PlateMateApp extends StatelessWidget {
  const PlateMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DietBloc()..add(LoadDiets()),
      child: MaterialApp(
        title: 'PlateMate',
        theme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark, // Forced Dark Mode
        debugShowCheckedModeBanner: false,
        home: const DietListScreen(),
      ),
    );
  }
}
