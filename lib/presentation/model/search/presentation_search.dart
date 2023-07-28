import 'package:equatable/equatable.dart';
import 'package:fluffychat/domain/model/search/search_model.dart';
import 'package:matrix/matrix.dart';

class PresentationSearch extends Equatable {

  final String? email;

  final String? displayName;

  final String? matrixId;

  final SearchElementTypeEnum? searchElementTypeEnum;

  final RoomSummary? roomSummary;

  final String? directChatMatrixID;

  const PresentationSearch({
    this.email,
    this.displayName,
    this.matrixId,
    this.searchElementTypeEnum,
    this.roomSummary,
    this.directChatMatrixID
  });

  bool get isContact => searchElementTypeEnum == SearchElementTypeEnum.contact;

  @override
  List<Object?> get props => [
    email,
    displayName,
    matrixId,
    searchElementTypeEnum,
    roomSummary,
    directChatMatrixID
  ];

  
}