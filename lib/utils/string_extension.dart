import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:file_saver/file_saver.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:intl/intl.dart';
import 'package:matrix/matrix.dart';
import 'package:crypto/crypto.dart';

extension StringCasingExtension on String {
  String removeDiacritics() {
    const withDia =
        'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    const withoutDia =
        'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';

    String str = this;
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }

    return str;
  }

  String getShortcutNameForAvatar() {
    final words = trim().split(RegExp('\\s+'));

    if (words.isEmpty || words[0] == '') {
      return '@';
    }

    final first = words[0];
    final last = words.length > 1 ? words[1] : '';
    final codeUnits = StringBuffer();

    if (first.isNotEmpty) {
      codeUnits.writeCharCode(first.runes.first);
    }

    if (last.isNotEmpty) {
      codeUnits.writeCharCode(last.runes.first);
    }

    return codeUnits.toString().toUpperCase();
  }

  String capitalize(BuildContext context) {
    return toBeginningOfSentenceCase(this, L10n.of(context)!.localeName) ??
        this;
  }

  bool isCurrentMatrixId(BuildContext context) {
    if (isEmpty) {
      return false;
    }
    return Matrix.of(context).client.userID == this;
  }

  List<String> getMentionsFromMessage() {
    final RegExp regex = RegExp(r"@\[([^\]]+)\]");
    final Iterable<Match> matches = regex.allMatches(this);

    final List<String> mentions = [];
    for (final Match match in matches) {
      final String? mention = match.group(0);
      if (mention != null) {
        mentions.add(mention);
      }
    }

    return mentions;
  }

  List<String> getAllMentionedUserIdsFromMessage(Room room) {
    final List<String> mentionUserIds = [];
    for (final String mention in getMentionsFromMessage()) {
      final String? userId = room.lastEvent?.room.getMention(mention);
      if (userId != null) {
        mentionUserIds.add(userId);
      }
    }

    return mentionUserIds;
  }

  String? getFirstValidUrl() {
    final RegExp regex = RegExp(r'https:\/\/[^\s]+', caseSensitive: false);
    final List<String?> matches =
        regex.allMatches(this).map((m) => m.group(0)).toList();

    if (matches.isEmpty) {
      return null;
    }

    final String? firstValidLink = matches.firstWhereOrNull((link) {
      if (link == null) return false;
      return Uri.tryParse(link)?.isAbsolute ?? false;
    });
    return firstValidLink;
  }

  // Removes markdowned links from a string based on the unformatted text
  // Workaround for content['formatted_body'] which formats urls in a way that makes them unusable
  String unMarkdownLinks(String unformattedText) {
    final RegExp regex = RegExp(r'https:\/\/[^\s]+');

    final Iterable<Match> formattedLinksMatches = regex.allMatches(this);
    final Iterable<Match> unformattedLinksMatches =
        regex.allMatches(unformattedText);

    if (formattedLinksMatches.isEmpty ||
        unformattedLinksMatches.isEmpty ||
        formattedLinksMatches.length != unformattedLinksMatches.length) {
      return this;
    }

    var unMarkdownedText = this;

    final Iterator<Match> formattedIterator = formattedLinksMatches.iterator;
    final Iterator<Match> unformattedIterator =
        unformattedLinksMatches.iterator;

    // Replace respectively all formatted links with unformatted links
    while (formattedIterator.moveNext() && unformattedIterator.moveNext()) {
      final Match formattedLinkMatch = formattedIterator.current;
      final Match unformattedLinkMatch = unformattedIterator.current;

      final String formattedLink = formattedLinkMatch.group(0)!;
      final String unformattedLink = unformattedLinkMatch.group(0)!;

      unMarkdownedText =
          unMarkdownedText.replaceFirst(formattedLink, unformattedLink);
    }

    return unMarkdownedText;
  }

  bool isEventIdOlderOrSameAs(Timeline timeline, String thatEventId) {
    if (timeline.events.isEmpty) return false;

    final firstEvent =
        timeline.events.firstWhereOrNull((e) => e.eventId == this);
    final secondEvent =
        timeline.events.firstWhereOrNull((e) => e.eventId == thatEventId);

    if (secondEvent == null || firstEvent == null) return false;

    return this == thatEventId ||
        timeline.events.indexOf(secondEvent) >
            timeline.events.indexOf(firstEvent);
  }

  MimeType toMimeTypeEnum() {
    switch (this) {
      case 'image/jpeg':
        return MimeType.jpeg;
      case 'image/png':
        return MimeType.png;
      case 'image/gif':
        return MimeType.gif;
      case 'image/bmp':
        return MimeType.bmp;
      case 'video/mpeg':
        return MimeType.mpeg;
      case 'video/x-msvideo':
        return MimeType.avi;
      case 'audio/mpeg':
        return MimeType.mp3;
      case 'audio/aac':
        return MimeType.aac;
      case 'application/pdf':
        return MimeType.pdf;
      case 'application/epub+zip':
        return MimeType.epub;
      case 'application/json':
        return MimeType.json;
      case 'font/otf':
        return MimeType.otf;
      case 'font/ttf':
        return MimeType.ttf;
      case 'application/zip':
        return MimeType.zip;
      case 'application/vnd.oasis.opendocument.presentation':
        return MimeType.openDocPresentation;
      case 'application/vnd.oasis.opendocument.text':
        return MimeType.openDocText;
      case 'application/vnd.oasis.opendocument.spreadsheet':
        return MimeType.openDocSheets;
      case 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
        return MimeType.microsoftExcel;
      case 'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        return MimeType.microsoftPresentation;
      case 'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        return MimeType.microsoftWord;
      case 'application/vnd.etsi.asic-e+zip':
        return MimeType.asice;
      case 'application/vnd.etsi.asic-s+zip':
        return MimeType.asics;
      case 'application/octet-stream':
        return MimeType.other;
      case 'text/plain':
        return MimeType.text;
      case 'text/csv':
        return MimeType.csv;
      default:
        return MimeType.other;
    }
  }

  bool containsWord(String word) {
    final containsWordRegex = RegExp(
      "\\b(?:$word)\\b",
      caseSensitive: false,
    );
    return containsWordRegex.hasMatch(this);
  }

  String htmlHighlightText(targetText) {
    final outsideHtmlTagRegex = RegExp(
      '(<[^>]*>)|(${RegExp.escape(targetText)})',
      caseSensitive: false,
    );

    final highlightedContent = replaceAllMapped(outsideHtmlTagRegex, (match) {
      if (match.group(1) != null) {
        return match.group(1)!;
      } else {
        return '<span data-mx-bg-color=gold>${match.group(2)}</span>';
      }
    });

    return highlightedContent;
  }

  List<TextSpan> buildHighlightTextSpans(
    String highlightText, {
    TextStyle? style,
    TextStyle? highlightStyle,
    GestureRecognizer? recognizer,
  }) {
    if (highlightText.isEmpty || isEmpty) {
      return [
        TextSpan(
          text: this,
          style: style,
          recognizer: recognizer,
        ),
      ];
    }

    // Split the text into parts by the search word and create a TextSpan for
    // each part. The search word is not case sensitive.
    final List<TextSpan> spans = splitMapJoinToList<TextSpan>(
      RegExp(highlightText, caseSensitive: false),
      onMatch: (Match match) {
        return TextSpan(
          text: match.group(0),
          style: highlightStyle,
          recognizer: recognizer,
        );
      },
      onNonMatch: (String nonMatch) {
        return TextSpan(
          text: nonMatch,
          style: style,
          recognizer: recognizer,
        );
      },
    );

    return spans;
  }

  List<T> splitMapJoinToList<T>(
    Pattern pattern, {
    required T Function(Match) onMatch,
    required T Function(String) onNonMatch,
  }) {
    final List<T> result = [];
    splitMapJoin(
      pattern,
      onMatch: (Match match) {
        result.add(onMatch(match));
        return '';
      },
      onNonMatch: (String nonMatch) {
        result.add(onNonMatch(nonMatch));
        return '';
      },
    );
    return result;
  }

  String shortenDisplayName({
    required int maxCharacters,
  }) {
    if (length < maxCharacters) return this;
    return substring(0, maxCharacters);
  }

  String substringToHighlight(String highlightText, {int prefixLength = 0}) {
    if (prefixLength < 0) return this;
    final index = toLowerCase().indexOf(highlightText.toLowerCase());
    if (index > prefixLength) {
      final enterIndex =
          substring(index - prefixLength, index).lastIndexOf(RegExp(r'\n'));
      if (enterIndex <= -1) {
        return '...${substring(index - prefixLength)}';
      }
      return '...${substring(index - prefixLength + enterIndex + 1)}';
    }
    if (index <= -1) {
      return this;
    }
    final enterIndex = substring(0, index).lastIndexOf(RegExp(r'\n'));
    if (enterIndex <= -1) {
      return this;
    }
    return '...${substring(enterIndex + 1)}';
  }

  String msisdnSanitizer() {
    var msisdn = trim();
    msisdn = msisdn.replaceAll("+", "");
    msisdn = msisdn.replaceAll(RegExp(r'[^0-9]'), '');
    return msisdn;
  }

  /// Ref: https://spec.matrix.org/v1.6/rooms/v4/#event-ids
  String get urlSafeBase64 {
    return replaceAll('+', '-').replaceAll('/', '_');
  }

  String get sha256Hash {
    return sha256.convert(utf8.encode(this)).toString();
  }

  String normalizePhoneNumber() {
    return replaceAll(RegExp(r'\D'), '');
  }

  bool isContainsHttpProtocol() {
    final urlRegExp = RegExp(
      r'(http://|https://)(www.)?([a-zA-Z0-9]+).[a-zA-Z0-9]*.[a-z]{2,}.?([a-z]+)?',
    );
    return urlRegExp.hasMatch(this);
  }

  String removeHttpProtocol() {
    final httpProtocolRegExp = RegExp(r'(http://|https://)');
    return replaceAll(httpProtocolRegExp, '');
  }
}
