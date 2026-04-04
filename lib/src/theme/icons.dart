import 'package:flutter/material.dart';

/// 앱의 커스텀 아이콘 매핑
///
/// Material Icons와 Cupertino Icons를 쉽게 사용하기 위한 매핑
/// 필요에 따라 커스텀 아이콘 폰트를 추가할 수 있습니다
///
/// 사용법: `AppIcons.back` 등 상수로 접근
/// 점진적으로 `Icons.xxx` 직접 사용을 `AppIcons.xxx`로 전환 예정
class AppIcons {
  AppIcons._();

  // ── Navigation ──────────────────────────────────────────────
  static const IconData home = Icons.home;
  static const IconData search = Icons.search;
  static const IconData profile = Icons.person;
  static const IconData settings = Icons.settings;
  static const IconData back = Icons.arrow_back;
  static const IconData backIos = Icons.arrow_back_ios;
  static const IconData close = Icons.close;
  static const IconData closeRounded = Icons.close_rounded;
  static const IconData menu = Icons.menu;
  static const IconData moreVert = Icons.more_vert;
  static const IconData chevronRight = Icons.chevron_right;
  static const IconData chevronLeft = Icons.chevron_left;
  static const IconData arrowDropDown = Icons.arrow_drop_down;
  static const IconData arrowForward = Icons.arrow_forward;
  static const IconData arrowUpwardRounded = Icons.arrow_upward_rounded;
  static const IconData keyboardArrowDown = Icons.keyboard_arrow_down;
  static const IconData keyboardArrowUp = Icons.keyboard_arrow_up;

  // ── Actions ─────────────────────────────────────────────────
  static const IconData add = Icons.add;
  static const IconData addCircleOutline = Icons.add_circle_outline;
  static const IconData edit = Icons.edit;
  static const IconData editNote = Icons.edit_note;
  static const IconData editNoteOutlined = Icons.edit_note_outlined;
  static const IconData delete = Icons.delete;
  static const IconData deleteOutline = Icons.delete_outline;
  static const IconData save = Icons.save;
  static const IconData share = Icons.share;
  static const IconData shareOutlined = Icons.share_outlined;
  static const IconData favorite = Icons.favorite;
  static const IconData favoriteBorder = Icons.favorite_border;
  static const IconData favoriteOutline = Icons.favorite_outline;
  static const IconData clear = Icons.clear;

  // ── Status ──────────────────────────────────────────────────
  static const IconData check = Icons.check;
  static const IconData checkCircle = Icons.check_circle;
  static const IconData checkCircleOutline = Icons.check_circle_outline;
  static const IconData checkCircleRounded = Icons.check_circle_rounded;
  static const IconData error = Icons.error;
  static const IconData errorOutline = Icons.error_outline;
  static const IconData errorRounded = Icons.error_rounded;
  static const IconData warning = Icons.warning;
  static const IconData warningAmber = Icons.warning_amber;
  static const IconData warningAmberRounded = Icons.warning_amber_rounded;
  static const IconData warningRounded = Icons.warning_rounded;
  static const IconData info = Icons.info;
  static const IconData infoOutline = Icons.info_outline;
  static const IconData infoRounded = Icons.info_rounded;
  static const IconData block = Icons.block;

  // ── Health & Medical ────────────────────────────────────────
  static const IconData healthAndSafety = Icons.health_and_safety;
  static const IconData healthAndSafetyOutlined = Icons.health_and_safety_outlined;
  static const IconData localHospital = Icons.local_hospital;
  static const IconData localHospitalOutlined = Icons.local_hospital_outlined;
  static const IconData monitorWeightOutlined = Icons.monitor_weight_outlined;
  static const IconData pets = Icons.pets;
  static const IconData scienceOutlined = Icons.science_outlined;

  // ── Records & Data ──────────────────────────────────────────
  static const IconData history = Icons.history;
  static const IconData accessTime = Icons.access_time;
  static const IconData calendarTodayOutlined = Icons.calendar_today_outlined;
  static const IconData editCalendarOutlined = Icons.edit_calendar_outlined;
  static const IconData eventOutlined = Icons.event_outlined;
  static const IconData eventNoteOutlined = Icons.event_note_outlined;
  static const IconData restaurant = Icons.restaurant;
  static const IconData showChart = Icons.show_chart;
  static const IconData trendingUp = Icons.trending_up;
  static const IconData trendingDown = Icons.trending_down;
  static const IconData trendingFlat = Icons.trending_flat;

  // ── Rating ──────────────────────────────────────────────────
  static const IconData starRounded = Icons.star_rounded;
  static const IconData starOutlineRounded = Icons.star_outline_rounded;

  // ── Media ───────────────────────────────────────────────────
  static const IconData image = Icons.image;
  static const IconData imageNotSupportedOutlined = Icons.image_not_supported_outlined;
  static const IconData camera = Icons.camera_alt;
  static const IconData cameraOutlined = Icons.camera_alt_outlined;
  static const IconData cameraRounded = Icons.camera_alt_rounded;
  static const IconData photoLibrary = Icons.photo_library;
  static const IconData video = Icons.videocam;
  static const IconData audio = Icons.audiotrack;

  // ── Communication ───────────────────────────────────────────
  static const IconData mail = Icons.mail;
  static const IconData emailOutlined = Icons.email_outlined;
  static const IconData notifications = Icons.notifications;
  static const IconData notificationsNone = Icons.notifications_none;
  static const IconData notificationsOutlined = Icons.notifications_outlined;
  static const IconData chat = Icons.chat;
  static const IconData call = Icons.call;

  // ── Premium & Account ───────────────────────────────────────
  static const IconData workspacePremium = Icons.workspace_premium;
  static const IconData lockOutline = Icons.lock_outline;
  static const IconData lock = Icons.lock;
  static const IconData language = Icons.language;

  // ── Common UI ───────────────────────────────────────────────
  static const IconData expand = Icons.expand_more;
  static const IconData collapse = Icons.expand_less;
  static const IconData filter = Icons.filter_list;
  static const IconData sort = Icons.sort;
  static const IconData refresh = Icons.refresh;
  static const IconData visibility = Icons.visibility;
  static const IconData visibilityOff = Icons.visibility_off;
  static const IconData lightbulbOutline = Icons.lightbulb_outline;
  static const IconData autoAwesome = Icons.auto_awesome;
  static const IconData wifiOffRounded = Icons.wifi_off_rounded;
}
