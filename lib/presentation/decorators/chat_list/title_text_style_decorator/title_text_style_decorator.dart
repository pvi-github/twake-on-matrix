import 'package:fluffychat/presentation/decorators/chat_list/title_text_style_decorator/title_text_style_component.dart';
import 'package:flutter/material.dart';
import 'package:linagora_design_flutter/linagora_design_flutter.dart';
import 'package:matrix/matrix.dart';

abstract class ChatListTitleTextStyleDecorator
    implements ChatListTitleTextStyleComponent {
  final ChatListTitleTextStyleComponent interfaceTextStyleComponent;

  ChatListTitleTextStyleDecorator(this.interfaceTextStyleComponent);
}

class ChatListTitleTextStyle implements ChatListTitleTextStyleDecorator {
  final ChatListTitleTextStyleComponent _interfaceTextStyleComponent;

  ChatListTitleTextStyle(this._interfaceTextStyleComponent);

  @override
  TextStyle textStyle(Room room) {
    return _interfaceTextStyleComponent.textStyle(room);
  }

  @override
  ChatListTitleTextStyleComponent get interfaceTextStyleComponent =>
      _interfaceTextStyleComponent;
}

class ReadChatListTitleTextStyleDecorator
    implements ChatListTitleTextStyleComponent {
  @override
  TextStyle textStyle(Room room) {
    return LinagoraTextStyle.material().bodyLarge2.copyWith(
          color: LinagoraSysColors.material().onSurface,
        );
  }
}

class UnreadChatListTitleTextStyleDecorator
    implements ChatListTitleTextStyleDecorator {
  final ChatListTitleTextStyleComponent _interfaceTextStyleComponent;

  UnreadChatListTitleTextStyleDecorator(this._interfaceTextStyleComponent);

  @override
  TextStyle textStyle(Room room) {
    final unread = room.isUnread || room.membership == Membership.invite;
    if (unread) {
      return _interfaceTextStyleComponent.textStyle(room).merge(
            LinagoraTextStyle.material().bodyLarge1.copyWith(
                  color: LinagoraSysColors.material().onSurface,
                ),
          );
    } else {
      return _interfaceTextStyleComponent.textStyle(room);
    }
  }

  @override
  ChatListTitleTextStyleComponent get interfaceTextStyleComponent =>
      _interfaceTextStyleComponent;
}

class MuteChatListTitleTextStyleDecorator
    implements ChatListTitleTextStyleDecorator {
  final ChatListTitleTextStyleComponent _interfaceTextStyleComponent;

  MuteChatListTitleTextStyleDecorator(this._interfaceTextStyleComponent);

  @override
  TextStyle textStyle(Room room) {
    final isMuted = room.pushRuleState != PushRuleState.notify;
    if (isMuted) {
      return _interfaceTextStyleComponent.textStyle(room).merge(
            LinagoraTextStyle.material().bodyLarge1.copyWith(
                  color: LinagoraRefColors.material().tertiary[20],
                ),
          );
    } else {
      return _interfaceTextStyleComponent.textStyle(room);
    }
  }

  @override
  ChatListTitleTextStyleComponent get interfaceTextStyleComponent =>
      _interfaceTextStyleComponent;
}