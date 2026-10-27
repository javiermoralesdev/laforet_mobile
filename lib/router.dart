import 'package:go_router/go_router.dart';
import 'package:laforet_mobile/routes/entry_view.dart';
import 'package:laforet_mobile/routes/entry_write.dart';
import 'package:laforet_mobile/routes/home_route.dart';
import 'package:material_ui/material_ui.dart';

final GoRouter router = GoRouter(
  routes: <RouteBase>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const HomeRoute();
      },
    ),
    GoRoute(
      path: '/entry',
      builder: (BuildContext context, GoRouterState state) {
        final entryID = state.uri.queryParameters["id"] ?? "";
        return EntryView(entryId: entryID);
      },
    ),
    GoRoute(
      path: '/write',
      builder: (BuildContext context, GoRouterState state) {
        return EntryWrite();
      },
    ),
  ],
);
