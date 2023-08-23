import 'package:async/async.dart';
import 'package:fluffychat/pages/chat_list/client_chooser_button.dart';
import 'package:fluffychat/widgets/layouts/adaptive_layout/adaptive_scaffold_view.dart';
import 'package:fluffychat/widgets/layouts/enum/adaptive_destinations_enum.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

typedef OnOpenSearchPage = Function();
typedef OnCloseSearchPage = Function();
typedef OnClientSelectedSetting = Function(Object object, BuildContext context);
typedef OnDestinationSelected = Function(int index);

class AdaptiveScaffoldApp extends StatefulWidget {
  final String? activeRoomId;

  const AdaptiveScaffoldApp({
    super.key,
    this.activeRoomId,
  });

  @override
  State<AdaptiveScaffoldApp> createState() => AdaptiveScaffoldAppController();
}

class AdaptiveScaffoldAppController extends State<AdaptiveScaffoldApp> {
  late final profileMemoizers = <Client?, AsyncMemoizer<Profile>>{};

  final ValueNotifier<AdaptiveDestinationEnum> activeNavigationBar =
      ValueNotifier<AdaptiveDestinationEnum>(AdaptiveDestinationEnum.rooms);

  final PageController pageController =
      PageController(initialPage: 1, keepPage: false);

  Future<Profile?> fetchOwnProfile() {
    if (!profileMemoizers.containsKey(matrix.client)) {
      profileMemoizers[matrix.client] = AsyncMemoizer();
    }
    return profileMemoizers[matrix.client]!.runOnce(() async {
      return await matrix.client.fetchOwnProfile();
    });
  }

  void onDestinationSelected(int index) {
    switch (index) {
      //FIXME: NOW WE SUPPORT FOR ONLY 2 TABS
      case 0:
        activeNavigationBar.value = AdaptiveDestinationEnum.contacts;
        pageController.jumpToPage(index);
        break;
      case 1:
        activeNavigationBar.value = AdaptiveDestinationEnum.rooms;
        pageController.jumpToPage(index);
        break;
      default:
        break;
    }
  }

  int get activeNavigationBarIndex {
    switch (activeNavigationBar.value) {
      case AdaptiveDestinationEnum.contacts:
        return 0;
      case AdaptiveDestinationEnum.rooms:
        return 1;
      default:
        return 1;
    }
  }

  void clientSelected(
    Object object,
    BuildContext context,
  ) async {
    if (object is SettingsAction) {
      switch (object) {
        case SettingsAction.settings:
          context.go('/rooms/settings');
          break;
        case SettingsAction.archive:
          context.go('/rooms/archive');
          break;
        case SettingsAction.addAccount:
        case SettingsAction.newStory:
        case SettingsAction.newSpace:
        case SettingsAction.invite:
          break;

        default:
          break;
      }
    }
  }

  void _onOpenSearchPage() {
    activeNavigationBar.value = AdaptiveDestinationEnum.search;
    pageController.jumpToPage(3);
  }

  void _onCloseSearchPage() {
    activeNavigationBar.value = AdaptiveDestinationEnum.rooms;
    pageController.jumpToPage(1);
  }

  MatrixState get matrix => Matrix.of(context);

  @override
  Widget build(BuildContext context) => AppScaffoldView(
        activeRoomId: widget.activeRoomId,
        activeNavigationBar: activeNavigationBar,
        pageController: pageController,
        fetchOwnProfile: fetchOwnProfile(),
        activeNavigationBarIndex: activeNavigationBarIndex,
        onOpenSearchPage: _onOpenSearchPage,
        onCloseSearchPage: _onCloseSearchPage,
        onDestinationSelected: onDestinationSelected,
        onClientSelected: clientSelected,
      );
}