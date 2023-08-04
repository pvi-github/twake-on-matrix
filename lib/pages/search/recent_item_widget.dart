import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/pages/search/recent_item_widget_style.dart';
import 'package:fluffychat/presentation/extensions/search/presentation_search_extensions.dart';
import 'package:fluffychat/presentation/model/search/presentation_search.dart';
import 'package:fluffychat/widgets/avatar/avatar.dart';
import 'package:fluffychat/widgets/highlight_text.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:linagora_design_flutter/linagora_design_flutter.dart';
import 'package:fluffychat/presentation/extensions/room_summary_extension.dart';
import 'package:matrix/matrix.dart';

class RecentItemWidget extends StatelessWidget {
  final PresentationSearch presentationSearch;
  final String highlightKeyword;
  final void Function()? onTap;

  const RecentItemWidget({
    required this.presentationSearch,
    required this.highlightKeyword,
    this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return Material(
      borderRadius: BorderRadius.circular(AppConfig.borderRadius),
      clipBehavior: Clip.hardEdge,
      color: Colors.transparent,
      child: Padding(
        padding: RecentItemStyle.paddingRecentItem,
        child: Theme(
          data: ThemeData(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: _buildInformationWidget(context),
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  Widget _buildInformationWidget(BuildContext context) {
    if (presentationSearch is ContactPresentationSearch) {
      return _ContactInformation(
        contactPresentationSearch: presentationSearch as ContactPresentationSearch,
        searchKeyword: highlightKeyword
      );
    } else {
      final recentChatPresentationSearch = presentationSearch as RecentChatPresentationSearch;
      if (recentChatPresentationSearch.directChatMatrixID == null) {
        return _GroupChatInformation(recentChatPresentationSearch: recentChatPresentationSearch);
      } else {
        return _DirectChatInformation(
          recentChatPresentationSearch: recentChatPresentationSearch,
          searchKeyword: highlightKeyword
        );
      }
    }
  }
}

class _GroupChatInformation extends StatelessWidget {
  final RecentChatPresentationSearch recentChatPresentationSearch;
  const _GroupChatInformation({required this.recentChatPresentationSearch});

  @override
  Widget build(BuildContext context) {
    final actualMembersCount = recentChatPresentationSearch.roomSummary?.actualMembersCount ?? 0;
    return Text(
      L10n.of(context)!.membersCount(actualMembersCount),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      softWrap: false,
      style: Theme.of(context).textTheme.bodyMedium?.merge(
        TextStyle(
          overflow: TextOverflow.ellipsis,
          letterSpacing: 0.15,
          color: LinagoraRefColors.material().tertiary[30],
        ),
      ),
    );
  }
}


class _DirectChatInformation extends StatelessWidget {
  final RecentChatPresentationSearch recentChatPresentationSearch;
  final String? searchKeyword;

  const _DirectChatInformation({required this.recentChatPresentationSearch, this.searchKeyword});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ///FIXME
        SizedBox(
          width: RecentItemStyle.avatarSize,
          child: Avatar(
            name: recentChatPresentationSearch.displayName,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HighlightText(
                text: recentChatPresentationSearch.displayName ?? "",
                style: Theme.of(context).textTheme.titleMedium?.merge(
                  TextStyle(
                    overflow: TextOverflow.ellipsis,
                    letterSpacing: 0.15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                searchWord: searchKeyword,
              ),
              HighlightText(
                text: recentChatPresentationSearch.directChatMatrixID ?? "",
                style: Theme.of(context).textTheme.bodyMedium?.merge(
                  TextStyle(
                    overflow: TextOverflow.ellipsis,
                    letterSpacing: 0.15,
                    color: LinagoraRefColors.material().tertiary[30],
                  ),
                ),
                searchWord: searchKeyword,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactInformation extends StatelessWidget {
  final ContactPresentationSearch contactPresentationSearch;
  final String? searchKeyword;

  const _ContactInformation({required this.contactPresentationSearch, this.searchKeyword});

  @override
  Widget build(BuildContext context) {
    final client = Matrix.of(context).client;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: RecentItemStyle.avatarSize,
          child: FutureBuilder<ProfileInformation?>(
              future: contactPresentationSearch.getProfile(client),
              builder: (context, snapshot) {
                return Avatar(
                  mxContent: snapshot.data?.avatarUrl,
                  name: contactPresentationSearch.displayName,
                );
              }
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HighlightText(
                text: contactPresentationSearch.displayName ?? "",
                style: Theme.of(context).textTheme.titleMedium?.merge(
                  TextStyle(
                    overflow: TextOverflow.ellipsis,
                    letterSpacing: 0.15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                searchWord: searchKeyword,
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (contactPresentationSearch.matrixId != null)
                    HighlightText(
                      text: contactPresentationSearch.matrixId ?? "",
                      style: Theme.of(context).textTheme.bodyMedium?.merge(
                        TextStyle(
                          overflow: TextOverflow.ellipsis,
                          letterSpacing: 0.15,
                          color: LinagoraRefColors.material().tertiary[30],
                        ),
                      ),
                      searchWord: searchKeyword,
                    ),
                  if (contactPresentationSearch.email != null)
                    HighlightText(
                      text: contactPresentationSearch.email ?? "",
                      style: Theme.of(context).textTheme.bodyMedium?.merge(
                        TextStyle(
                          overflow: TextOverflow.ellipsis,
                          letterSpacing: 0.15,
                          color: LinagoraRefColors.material().tertiary[30],
                        ),
                      ),
                      searchWord: searchKeyword,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
