import 'package:flutter/material.dart';

/// 앱의 커스텀 아이콘 매핑
///
/// Material Icons와 Cupertino Icons를 쉽게 사용하기 위한 매핑
/// 필요에 따라 커스텀 아이콘 폰트를 추가할 수 있습니다
class AppIcons {
  AppIcons._();

  // Navigation
  static const IconData home = Icons.home;
  static const IconData search = Icons.search;
  static const IconData profile = Icons.person;
  static const IconData settings = Icons.settings;
  static const IconData back = Icons.arrow_back;
  static const IconData close = Icons.close;
  static const IconData menu = Icons.menu;

  // Actions
  static const IconData add = Icons.add;
  static const IconData edit = Icons.edit;
  static const IconData delete = Icons.delete;
  static const IconData save = Icons.save;
  static const IconData share = Icons.share;
  static const IconData favorite = Icons.favorite;
  static const IconData favoriteBorder = Icons.favorite_border;

  // Status
  static const IconData check = Icons.check;
  static const IconData error = Icons.error;
  static const IconData warning = Icons.warning;
  static const IconData info = Icons.info;

  // Media
  static const IconData image = Icons.image;
  static const IconData camera = Icons.camera_alt;
  static const IconData video = Icons.videocam;
  static const IconData audio = Icons.audiotrack;

  // Communication
  static const IconData mail = Icons.mail;
  static const IconData notifications = Icons.notifications;
  static const IconData chat = Icons.chat;
  static const IconData call = Icons.call;

  // Common UI
  static const IconData expand = Icons.expand_more;
  static const IconData collapse = Icons.expand_less;
  static const IconData filter = Icons.filter_list;
  static const IconData sort = Icons.sort;
  static const IconData refresh = Icons.refresh;
  static const IconData visibility = Icons.visibility;
  static const IconData visibilityOff = Icons.visibility_off;
}
