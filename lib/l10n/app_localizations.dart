import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ko'),
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @common_save.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get common_save;

  /// No description provided for @common_cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get common_cancel;

  /// No description provided for @common_confirm.
  ///
  /// In ko, this message translates to:
  /// **'확인'**
  String get common_confirm;

  /// No description provided for @common_close.
  ///
  /// In ko, this message translates to:
  /// **'닫기'**
  String get common_close;

  /// No description provided for @common_delete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get common_delete;

  /// No description provided for @common_edit.
  ///
  /// In ko, this message translates to:
  /// **'수정'**
  String get common_edit;

  /// No description provided for @common_later.
  ///
  /// In ko, this message translates to:
  /// **'나중에 하기'**
  String get common_later;

  /// No description provided for @common_view.
  ///
  /// In ko, this message translates to:
  /// **'보기'**
  String get common_view;

  /// No description provided for @common_noData.
  ///
  /// In ko, this message translates to:
  /// **'데이터가 없습니다'**
  String get common_noData;

  /// No description provided for @common_loading.
  ///
  /// In ko, this message translates to:
  /// **'로딩 중...'**
  String get common_loading;

  /// No description provided for @common_saveSuccess.
  ///
  /// In ko, this message translates to:
  /// **'저장되었습니다.'**
  String get common_saveSuccess;

  /// No description provided for @common_saveError.
  ///
  /// In ko, this message translates to:
  /// **'저장 중 오류가 발생했습니다: {error}'**
  String common_saveError(String error);

  /// No description provided for @common_updated.
  ///
  /// In ko, this message translates to:
  /// **'수정되었습니다.'**
  String get common_updated;

  /// No description provided for @common_registered.
  ///
  /// In ko, this message translates to:
  /// **'등록되었습니다.'**
  String get common_registered;

  /// No description provided for @common_collapse.
  ///
  /// In ko, this message translates to:
  /// **'접기'**
  String get common_collapse;

  /// No description provided for @common_showAll.
  ///
  /// In ko, this message translates to:
  /// **'전체 보기 ({count}건)'**
  String common_showAll(int count);

  /// No description provided for @pet_loadError.
  ///
  /// In ko, this message translates to:
  /// **'펫 정보를 불러오는데 실패했습니다.'**
  String get pet_loadError;

  /// No description provided for @onboarding_title.
  ///
  /// In ko, this message translates to:
  /// **'만나서 반가워요!'**
  String get onboarding_title;

  /// No description provided for @onboarding_description.
  ///
  /// In ko, this message translates to:
  /// **'단순한 기록을 넘어, AI 분석으로 앵무새의\n상태를 더 깊이 이해해 보세요.'**
  String get onboarding_description;

  /// No description provided for @btn_start.
  ///
  /// In ko, this message translates to:
  /// **'시작하기'**
  String get btn_start;

  /// No description provided for @login_title.
  ///
  /// In ko, this message translates to:
  /// **'로그인'**
  String get login_title;

  /// No description provided for @login_kakao.
  ///
  /// In ko, this message translates to:
  /// **'카카오 로그인'**
  String get login_kakao;

  /// No description provided for @login_google.
  ///
  /// In ko, this message translates to:
  /// **'구글로 로그인'**
  String get login_google;

  /// No description provided for @login_apple.
  ///
  /// In ko, this message translates to:
  /// **'애플로 로그인'**
  String get login_apple;

  /// No description provided for @login_button.
  ///
  /// In ko, this message translates to:
  /// **'로그인'**
  String get login_button;

  /// No description provided for @login_notMember.
  ///
  /// In ko, this message translates to:
  /// **'아직 회원이 아니신가요?'**
  String get login_notMember;

  /// No description provided for @login_signup.
  ///
  /// In ko, this message translates to:
  /// **'회원가입'**
  String get login_signup;

  /// No description provided for @login_saveId.
  ///
  /// In ko, this message translates to:
  /// **'아이디 저장'**
  String get login_saveId;

  /// No description provided for @login_findIdPassword.
  ///
  /// In ko, this message translates to:
  /// **'아이디/비밀번호 찾기'**
  String get login_findIdPassword;

  /// No description provided for @input_email.
  ///
  /// In ko, this message translates to:
  /// **'이메일'**
  String get input_email;

  /// No description provided for @input_email_hint.
  ///
  /// In ko, this message translates to:
  /// **'이메일을 입력해 주세요'**
  String get input_email_hint;

  /// No description provided for @input_password.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호'**
  String get input_password;

  /// No description provided for @input_password_hint.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호를 입력해 주세요'**
  String get input_password_hint;

  /// No description provided for @input_name.
  ///
  /// In ko, this message translates to:
  /// **'이름'**
  String get input_name;

  /// No description provided for @input_name_hint.
  ///
  /// In ko, this message translates to:
  /// **'이름을 입력해 주세요'**
  String get input_name_hint;

  /// No description provided for @dialog_kakaoLoginTitle.
  ///
  /// In ko, this message translates to:
  /// **'카카오 로그인 안내'**
  String get dialog_kakaoLoginTitle;

  /// No description provided for @dialog_kakaoLoginContent1.
  ///
  /// In ko, this message translates to:
  /// **'카카오 정책으로 인해 바로 로그인할 수 없습니다.'**
  String get dialog_kakaoLoginContent1;

  /// No description provided for @dialog_kakaoLoginContent2.
  ///
  /// In ko, this message translates to:
  /// **'먼저 이메일로 회원가입 후, 마이페이지에서 카카오 계정을 연동하시면 다음부터 카카오 로그인을 사용할 수 있습니다.'**
  String get dialog_kakaoLoginContent2;

  /// No description provided for @dialog_goSignup.
  ///
  /// In ko, this message translates to:
  /// **'회원가입하기'**
  String get dialog_goSignup;

  /// No description provided for @signup_title.
  ///
  /// In ko, this message translates to:
  /// **'가입하기'**
  String get signup_title;

  /// No description provided for @signup_button.
  ///
  /// In ko, this message translates to:
  /// **'회원가입'**
  String get signup_button;

  /// No description provided for @signup_alreadyMember.
  ///
  /// In ko, this message translates to:
  /// **'이미 계정이 있으신가요?'**
  String get signup_alreadyMember;

  /// No description provided for @signup_completeTitle.
  ///
  /// In ko, this message translates to:
  /// **'회원가입 완료'**
  String get signup_completeTitle;

  /// No description provided for @signup_completeMessage.
  ///
  /// In ko, this message translates to:
  /// **'회원가입이 완료되었습니다!\n로그인 후 서비스를 이용할 수 있습니다.'**
  String get signup_completeMessage;

  /// No description provided for @terms_agreeAll.
  ///
  /// In ko, this message translates to:
  /// **'전체 동의'**
  String get terms_agreeAll;

  /// No description provided for @terms_requiredTerms.
  ///
  /// In ko, this message translates to:
  /// **'[필수] 이용약관 동의'**
  String get terms_requiredTerms;

  /// No description provided for @terms_requiredPrivacy.
  ///
  /// In ko, this message translates to:
  /// **'[필수] 개인정보 수집 및 이용 동의'**
  String get terms_requiredPrivacy;

  /// No description provided for @terms_optionalMarketing.
  ///
  /// In ko, this message translates to:
  /// **'[선택] 마케팅 정보 수신 동의'**
  String get terms_optionalMarketing;

  /// No description provided for @terms_termsOfService.
  ///
  /// In ko, this message translates to:
  /// **'이용약관'**
  String get terms_termsOfService;

  /// No description provided for @terms_privacyPolicy.
  ///
  /// In ko, this message translates to:
  /// **'개인정보처리방침'**
  String get terms_privacyPolicy;

  /// No description provided for @terms_sectionTitle.
  ///
  /// In ko, this message translates to:
  /// **'약관 및 정책'**
  String get terms_sectionTitle;

  /// No description provided for @forgot_title.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 찾기'**
  String get forgot_title;

  /// No description provided for @forgot_description.
  ///
  /// In ko, this message translates to:
  /// **'가입 시 사용한 이메일을 입력해 주세요.\n비밀번호 재설정 코드를 보내드립니다.'**
  String get forgot_description;

  /// No description provided for @btn_sendCode.
  ///
  /// In ko, this message translates to:
  /// **'코드 보내기'**
  String get btn_sendCode;

  /// No description provided for @forgot_codeTitle.
  ///
  /// In ko, this message translates to:
  /// **'코드 입력'**
  String get forgot_codeTitle;

  /// No description provided for @forgot_codeDescription.
  ///
  /// In ko, this message translates to:
  /// **'복구 코드가 귀하에게 전달되었습니다.\n전달 받은 코드를 2분안에 입력 하시길 바랍니다.'**
  String get forgot_codeDescription;

  /// No description provided for @forgot_codeSentTo.
  ///
  /// In ko, this message translates to:
  /// **'{destination}(으)로 코드를 보냈습니다.'**
  String forgot_codeSentTo(String destination);

  /// No description provided for @forgot_timeRemaining.
  ///
  /// In ko, this message translates to:
  /// **'코드 입력까지 {time} 남았습니다.'**
  String forgot_timeRemaining(String time);

  /// No description provided for @btn_resendCode.
  ///
  /// In ko, this message translates to:
  /// **'코드 다시 보내기'**
  String get btn_resendCode;

  /// No description provided for @forgot_newPasswordTitle.
  ///
  /// In ko, this message translates to:
  /// **'새로운 비밀번호'**
  String get forgot_newPasswordTitle;

  /// No description provided for @forgot_newPasswordDescription.
  ///
  /// In ko, this message translates to:
  /// **'새로운 비밀번호를 입력해 주세요,\n이전에 사용하신 비밀번호는 사용 하실 수 없습니다.'**
  String get forgot_newPasswordDescription;

  /// No description provided for @input_newPassword.
  ///
  /// In ko, this message translates to:
  /// **'새로운 비밀번호'**
  String get input_newPassword;

  /// No description provided for @input_confirmPassword.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 재입력'**
  String get input_confirmPassword;

  /// No description provided for @btn_resetComplete.
  ///
  /// In ko, this message translates to:
  /// **'재설정 완료'**
  String get btn_resetComplete;

  /// No description provided for @home_monthlyUnit.
  ///
  /// In ko, this message translates to:
  /// **'매월 단위'**
  String get home_monthlyUnit;

  /// No description provided for @home_weeklyUnit.
  ///
  /// In ko, this message translates to:
  /// **'매주 단위'**
  String get home_weeklyUnit;

  /// No description provided for @home_wciHealthStatus.
  ///
  /// In ko, this message translates to:
  /// **'WCI* 건강 상태'**
  String get home_wciHealthStatus;

  /// No description provided for @home_updatedAgo.
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분 전에 업데이트됨'**
  String home_updatedAgo(int minutes);

  /// No description provided for @home_enterDataPrompt.
  ///
  /// In ko, this message translates to:
  /// **'데이터를 입력해 {petName}의'**
  String home_enterDataPrompt(String petName);

  /// No description provided for @home_checkStatus.
  ///
  /// In ko, this message translates to:
  /// **'상태를 확인해 보세요.'**
  String get home_checkStatus;

  /// No description provided for @home_level.
  ///
  /// In ko, this message translates to:
  /// **'{level}단계'**
  String home_level(int level);

  /// No description provided for @home_weight.
  ///
  /// In ko, this message translates to:
  /// **'체중'**
  String get home_weight;

  /// No description provided for @home_weightHint.
  ///
  /// In ko, this message translates to:
  /// **'체중을 입력해주세요'**
  String get home_weightHint;

  /// No description provided for @home_food.
  ///
  /// In ko, this message translates to:
  /// **'사료'**
  String get home_food;

  /// No description provided for @home_foodHint.
  ///
  /// In ko, this message translates to:
  /// **'취식량을 입력해주세요'**
  String get home_foodHint;

  /// No description provided for @home_water.
  ///
  /// In ko, this message translates to:
  /// **'수분'**
  String get home_water;

  /// No description provided for @home_waterHint.
  ///
  /// In ko, this message translates to:
  /// **'음수량을 입력해주세요'**
  String get home_waterHint;

  /// No description provided for @home_todayHealthSignal.
  ///
  /// In ko, this message translates to:
  /// **'오늘의'**
  String get home_todayHealthSignal;

  /// No description provided for @home_healthSignal.
  ///
  /// In ko, this message translates to:
  /// **'건강 신호'**
  String get home_healthSignal;

  /// No description provided for @home_monthFormat.
  ///
  /// In ko, this message translates to:
  /// **'{month}월'**
  String home_monthFormat(int month);

  /// No description provided for @home_weekFormat.
  ///
  /// In ko, this message translates to:
  /// **'{week}주'**
  String home_weekFormat(int week);

  /// No description provided for @wci_level1.
  ///
  /// In ko, this message translates to:
  /// **'몸이 가볍고 마른 인상이 강해요.\n식사량이나 컨디션을 한 번 더 살펴보는 게 좋아요.'**
  String get wci_level1;

  /// No description provided for @wci_level2.
  ///
  /// In ko, this message translates to:
  /// **'갈비뼈가 보이지는 않지만 살짝 만지면 쉽게 느껴져요.\n옆에서 봤을 때 배가 쏙 들어간 부분이 보여요.'**
  String get wci_level2;

  /// No description provided for @wci_level3.
  ///
  /// In ko, this message translates to:
  /// **'전체적인 체형은 안정적이에요.\n지금 습관을 유지하면서 가볍게 관찰해 주세요.'**
  String get wci_level3;

  /// No description provided for @wci_level4.
  ///
  /// In ko, this message translates to:
  /// **'몸이 전체적으로 둥글어 보여요.\n식사량과 간식을 한 번 점검해 보세요.'**
  String get wci_level4;

  /// No description provided for @wci_level5.
  ///
  /// In ko, this message translates to:
  /// **'전체적으로 무거운 인상이 들어요.\n건강을 위해 식단과 활동을 조절하는 것이 좋아요.'**
  String get wci_level5;

  /// No description provided for @weight_title.
  ///
  /// In ko, this message translates to:
  /// **'체중'**
  String get weight_title;

  /// No description provided for @weight_wciHealthStatus.
  ///
  /// In ko, this message translates to:
  /// **'WCI 건강 상태'**
  String get weight_wciHealthStatus;

  /// No description provided for @weight_inputWeight.
  ///
  /// In ko, this message translates to:
  /// **'체중 입력'**
  String get weight_inputWeight;

  /// No description provided for @weight_inputHint.
  ///
  /// In ko, this message translates to:
  /// **'예: 58.3'**
  String get weight_inputHint;

  /// No description provided for @weight_formula.
  ///
  /// In ko, this message translates to:
  /// **'계산 공식'**
  String get weight_formula;

  /// No description provided for @weight_formulaText.
  ///
  /// In ko, this message translates to:
  /// **'WCI(%) = (현재 체중 - 기준 체중) ÷ 기준 체중 × 100'**
  String get weight_formulaText;

  /// No description provided for @weight_calculation.
  ///
  /// In ko, this message translates to:
  /// **'계산 과정'**
  String get weight_calculation;

  /// No description provided for @weight_noData.
  ///
  /// In ko, this message translates to:
  /// **'데이터가 없습니다.'**
  String get weight_noData;

  /// No description provided for @weight_level0Title.
  ///
  /// In ko, this message translates to:
  /// **'Level 0'**
  String get weight_level0Title;

  /// No description provided for @weight_level0Desc.
  ///
  /// In ko, this message translates to:
  /// **'몸무게를 입력해 주세요'**
  String get weight_level0Desc;

  /// No description provided for @weight_level1Title.
  ///
  /// In ko, this message translates to:
  /// **'Level 1 | 가벼운 상태'**
  String get weight_level1Title;

  /// No description provided for @weight_level1Desc.
  ///
  /// In ko, this message translates to:
  /// **'몸이 많이 가벼워요. 식사량과 컨디션을 점검해 주세요.'**
  String get weight_level1Desc;

  /// No description provided for @weight_level2Title.
  ///
  /// In ko, this message translates to:
  /// **'Level 2 | 약간 가벼운 상태'**
  String get weight_level2Title;

  /// No description provided for @weight_level2Desc.
  ///
  /// In ko, this message translates to:
  /// **'슬림한 편이에요. 현재 습관을 유지하며 관찰하세요.'**
  String get weight_level2Desc;

  /// No description provided for @weight_level3Title.
  ///
  /// In ko, this message translates to:
  /// **'Level 3 | 이상적인 상태'**
  String get weight_level3Title;

  /// No description provided for @weight_level3Desc.
  ///
  /// In ko, this message translates to:
  /// **'체중 균형이 가장 좋은 범위에 있어요. 현재 상태를 유지하는 것이 좋아요.'**
  String get weight_level3Desc;

  /// No description provided for @weight_level4Title.
  ///
  /// In ko, this message translates to:
  /// **'Level 4 | 약간 무거운 상태'**
  String get weight_level4Title;

  /// No description provided for @weight_level4Desc.
  ///
  /// In ko, this message translates to:
  /// **'몸이 조금 묵직해 보여요. 식사 균형을 점검해 보세요.'**
  String get weight_level4Desc;

  /// No description provided for @weight_level5Title.
  ///
  /// In ko, this message translates to:
  /// **'Level 5 | 무거운 상태'**
  String get weight_level5Title;

  /// No description provided for @weight_level5Desc.
  ///
  /// In ko, this message translates to:
  /// **'체중이 많이 늘었어요. 식단과 활동 조절이 필요해요.'**
  String get weight_level5Desc;

  /// No description provided for @weight_unitGram.
  ///
  /// In ko, this message translates to:
  /// **'g'**
  String get weight_unitGram;

  /// No description provided for @weightDetail_title.
  ///
  /// In ko, this message translates to:
  /// **'기록'**
  String get weightDetail_title;

  /// No description provided for @weightDetail_headerLine1.
  ///
  /// In ko, this message translates to:
  /// **'꾸준히 기록을 남기며'**
  String get weightDetail_headerLine1;

  /// No description provided for @weightDetail_headerLine2.
  ///
  /// In ko, this message translates to:
  /// **'{petName} 체중 변화를 한 눈에!'**
  String weightDetail_headerLine2(String petName);

  /// No description provided for @weightDetail_subLine1.
  ///
  /// In ko, this message translates to:
  /// **'지금 바로 기록하고 우리 아이 건강 상태를'**
  String get weightDetail_subLine1;

  /// No description provided for @weightDetail_subLine2.
  ///
  /// In ko, this message translates to:
  /// **'편하게 관리해 보세요.'**
  String get weightDetail_subLine2;

  /// No description provided for @weightDetail_toggleWeek.
  ///
  /// In ko, this message translates to:
  /// **'주'**
  String get weightDetail_toggleWeek;

  /// No description provided for @weightDetail_toggleMonth.
  ///
  /// In ko, this message translates to:
  /// **'월'**
  String get weightDetail_toggleMonth;

  /// No description provided for @weightDetail_recordSummary.
  ///
  /// In ko, this message translates to:
  /// **'{petName}의 몸무게 총 {days}일 기록 중'**
  String weightDetail_recordSummary(String petName, int days);

  /// No description provided for @weightDetail_yearMonth.
  ///
  /// In ko, this message translates to:
  /// **'{year}년 {month}월'**
  String weightDetail_yearMonth(int year, int month);

  /// No description provided for @weightDetail_monthChartLabel.
  ///
  /// In ko, this message translates to:
  /// **'{month}월'**
  String weightDetail_monthChartLabel(int month);

  /// No description provided for @schedule_dateDisplay.
  ///
  /// In ko, this message translates to:
  /// **'{month}월 {day}일 ({weekday})'**
  String schedule_dateDisplay(int month, int day, String weekday);

  /// No description provided for @weightDetail_noPet.
  ///
  /// In ko, this message translates to:
  /// **'활성화된 펫이 없습니다. 펫을 먼저 추가해주세요.'**
  String get weightDetail_noPet;

  /// No description provided for @weightDetail_noSchedule.
  ///
  /// In ko, this message translates to:
  /// **'등록된 일정이 없습니다'**
  String get weightDetail_noSchedule;

  /// No description provided for @weightDetail_addScheduleHint.
  ///
  /// In ko, this message translates to:
  /// **'아래 버튼을 눌러 일정을 추가해보세요'**
  String get weightDetail_addScheduleHint;

  /// No description provided for @weightDetail_monthSchedule.
  ///
  /// In ko, this message translates to:
  /// **'이번 달 일정'**
  String get weightDetail_monthSchedule;

  /// No description provided for @weightDetail_noWeightRecord.
  ///
  /// In ko, this message translates to:
  /// **'이번 달 체중 기록이 없습니다'**
  String get weightDetail_noWeightRecord;

  /// No description provided for @weightDetail_monthWeightRecord.
  ///
  /// In ko, this message translates to:
  /// **'{month}월 체중 기록'**
  String weightDetail_monthWeightRecord(int month);

  /// No description provided for @btn_addRecord.
  ///
  /// In ko, this message translates to:
  /// **'기록 추가'**
  String get btn_addRecord;

  /// No description provided for @weightDetail_today.
  ///
  /// In ko, this message translates to:
  /// **'오늘'**
  String get weightDetail_today;

  /// No description provided for @profile_title.
  ///
  /// In ko, this message translates to:
  /// **'프로필'**
  String get profile_title;

  /// No description provided for @profile_myPets.
  ///
  /// In ko, this message translates to:
  /// **'나의 반려가족'**
  String get profile_myPets;

  /// No description provided for @profile_addNewPet.
  ///
  /// In ko, this message translates to:
  /// **'새로운 아이 등록하기'**
  String get profile_addNewPet;

  /// No description provided for @pet_delete.
  ///
  /// In ko, this message translates to:
  /// **'반려동물 삭제'**
  String get pet_delete;

  /// No description provided for @pet_deleteConfirmTitle.
  ///
  /// In ko, this message translates to:
  /// **'반려동물 삭제'**
  String get pet_deleteConfirmTitle;

  /// No description provided for @pet_deleteConfirmMessage.
  ///
  /// In ko, this message translates to:
  /// **'이 반려동물을 삭제하시겠습니까? 체중, 사료, 수분 기록 등 모든 관련 데이터가 영구적으로 삭제됩니다.'**
  String get pet_deleteConfirmMessage;

  /// No description provided for @pet_deleteConfirmButton.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get pet_deleteConfirmButton;

  /// No description provided for @profile_socialAccounts.
  ///
  /// In ko, this message translates to:
  /// **'소셜 계정 연동'**
  String get profile_socialAccounts;

  /// No description provided for @profile_link.
  ///
  /// In ko, this message translates to:
  /// **'연동'**
  String get profile_link;

  /// No description provided for @profile_unlink.
  ///
  /// In ko, this message translates to:
  /// **'해제'**
  String get profile_unlink;

  /// No description provided for @profile_appSupport.
  ///
  /// In ko, this message translates to:
  /// **'앱 지원'**
  String get profile_appSupport;

  /// No description provided for @profile_rateApp.
  ///
  /// In ko, this message translates to:
  /// **'앱 평가하기'**
  String get profile_rateApp;

  /// No description provided for @profile_accountManagement.
  ///
  /// In ko, this message translates to:
  /// **'계정 관리'**
  String get profile_accountManagement;

  /// No description provided for @profile_logout.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get profile_logout;

  /// No description provided for @profile_deleteAccount.
  ///
  /// In ko, this message translates to:
  /// **'회원 탈퇴'**
  String get profile_deleteAccount;

  /// No description provided for @profile_noSpecies.
  ///
  /// In ko, this message translates to:
  /// **'종 정보 없음'**
  String get profile_noSpecies;

  /// No description provided for @profile_noAge.
  ///
  /// In ko, this message translates to:
  /// **'나이 정보 없음'**
  String get profile_noAge;

  /// No description provided for @profile_ageFormat.
  ///
  /// In ko, this message translates to:
  /// **'{years}년 {months}개월 {days}일'**
  String profile_ageFormat(int years, int months, int days);

  /// No description provided for @dialog_unlinkTitle.
  ///
  /// In ko, this message translates to:
  /// **'소셜 계정 연동 해제'**
  String get dialog_unlinkTitle;

  /// No description provided for @dialog_unlinkContent.
  ///
  /// In ko, this message translates to:
  /// **'{provider} 계정 연동을 해제하시겠습니까?'**
  String dialog_unlinkContent(String provider);

  /// No description provided for @dialog_logoutTitle.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get dialog_logoutTitle;

  /// No description provided for @dialog_logoutContent.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃 하시겠습니까?'**
  String get dialog_logoutContent;

  /// No description provided for @dialog_deleteAccountTitle.
  ///
  /// In ko, this message translates to:
  /// **'회원 탈퇴'**
  String get dialog_deleteAccountTitle;

  /// No description provided for @dialog_deleteAccountContent.
  ///
  /// In ko, this message translates to:
  /// **'탈퇴하시면 모든 데이터가 삭제되며 복구할 수 없습니다.\n정말 탈퇴하시겠습니까?'**
  String get dialog_deleteAccountContent;

  /// No description provided for @dialog_delete.
  ///
  /// In ko, this message translates to:
  /// **'탈퇴'**
  String get dialog_delete;

  /// No description provided for @pet_profile.
  ///
  /// In ko, this message translates to:
  /// **'프로필'**
  String get pet_profile;

  /// No description provided for @pet_name_hint.
  ///
  /// In ko, this message translates to:
  /// **'이름을 입력해 주세요'**
  String get pet_name_hint;

  /// No description provided for @pet_gender_hint.
  ///
  /// In ko, this message translates to:
  /// **'성별을 선택해 주세요'**
  String get pet_gender_hint;

  /// No description provided for @pet_weight_hint.
  ///
  /// In ko, this message translates to:
  /// **'몸무게'**
  String get pet_weight_hint;

  /// No description provided for @pet_birthday_hint.
  ///
  /// In ko, this message translates to:
  /// **'생일'**
  String get pet_birthday_hint;

  /// No description provided for @pet_adoptionDate_hint.
  ///
  /// In ko, this message translates to:
  /// **'가족이 된 날'**
  String get pet_adoptionDate_hint;

  /// No description provided for @pet_species_hint.
  ///
  /// In ko, this message translates to:
  /// **'종'**
  String get pet_species_hint;

  /// No description provided for @pet_growthStage_hint.
  ///
  /// In ko, this message translates to:
  /// **'성장 단계를 선택해 주세요'**
  String get pet_growthStage_hint;

  /// No description provided for @pet_genderMale.
  ///
  /// In ko, this message translates to:
  /// **'수컷'**
  String get pet_genderMale;

  /// No description provided for @pet_genderFemale.
  ///
  /// In ko, this message translates to:
  /// **'암컷'**
  String get pet_genderFemale;

  /// No description provided for @pet_genderUnknown.
  ///
  /// In ko, this message translates to:
  /// **'모름'**
  String get pet_genderUnknown;

  /// No description provided for @pet_growthRapid.
  ///
  /// In ko, this message translates to:
  /// **'빠른성장'**
  String get pet_growthRapid;

  /// No description provided for @pet_growthPost.
  ///
  /// In ko, this message translates to:
  /// **'후속성장'**
  String get pet_growthPost;

  /// No description provided for @pet_growthAdult.
  ///
  /// In ko, this message translates to:
  /// **'청년'**
  String get pet_growthAdult;

  /// No description provided for @dialog_selectGender.
  ///
  /// In ko, this message translates to:
  /// **'성별 선택'**
  String get dialog_selectGender;

  /// No description provided for @dialog_selectGrowthStage.
  ///
  /// In ko, this message translates to:
  /// **'성장 단계 선택'**
  String get dialog_selectGrowthStage;

  /// No description provided for @error_googleLogin.
  ///
  /// In ko, this message translates to:
  /// **'Google 로그인 중 오류가 발생했습니다.'**
  String get error_googleLogin;

  /// No description provided for @error_appleLogin.
  ///
  /// In ko, this message translates to:
  /// **'Apple 로그인 중 오류가 발생했습니다.'**
  String get error_appleLogin;

  /// No description provided for @error_kakaoLogin.
  ///
  /// In ko, this message translates to:
  /// **'Kakao 로그인 중 오류가 발생했습니다.'**
  String get error_kakaoLogin;

  /// No description provided for @error_login.
  ///
  /// In ko, this message translates to:
  /// **'로그인 중 오류가 발생했습니다.'**
  String get error_login;

  /// No description provided for @error_loginRetry.
  ///
  /// In ko, this message translates to:
  /// **'로그인 중 오류가 발생했습니다. 다시 시도해주세요.'**
  String get error_loginRetry;

  /// No description provided for @error_sendCode.
  ///
  /// In ko, this message translates to:
  /// **'코드 전송 중 오류가 발생했습니다.'**
  String get error_sendCode;

  /// No description provided for @error_invalidCode.
  ///
  /// In ko, this message translates to:
  /// **'코드가 올바르지 않습니다. 다시 확인해 주세요.'**
  String get error_invalidCode;

  /// No description provided for @error_passwordChange.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호 변경 중 오류가 발생했습니다.'**
  String get error_passwordChange;

  /// No description provided for @error_unexpected.
  ///
  /// In ko, this message translates to:
  /// **'예상치 못한 오류가 발생했습니다. 다시 시도해 주세요.'**
  String get error_unexpected;

  /// No description provided for @error_saveFailed.
  ///
  /// In ko, this message translates to:
  /// **'저장 중 오류가 발생했습니다: {error}'**
  String error_saveFailed(String error);

  /// No description provided for @error_loadPet.
  ///
  /// In ko, this message translates to:
  /// **'펫 정보를 불러오는데 실패했습니다.'**
  String get error_loadPet;

  /// No description provided for @error_deleteAccount.
  ///
  /// In ko, this message translates to:
  /// **'회원 탈퇴에 실패했습니다. 다시 시도해주세요.'**
  String get error_deleteAccount;

  /// No description provided for @error_linkGoogle.
  ///
  /// In ko, this message translates to:
  /// **'Google 계정 연동에 실패했습니다.'**
  String get error_linkGoogle;

  /// No description provided for @error_linkApple.
  ///
  /// In ko, this message translates to:
  /// **'Apple 계정 연동에 실패했습니다.'**
  String get error_linkApple;

  /// No description provided for @error_linkKakao.
  ///
  /// In ko, this message translates to:
  /// **'카카오 계정 연동에 실패했습니다.'**
  String get error_linkKakao;

  /// No description provided for @error_unlinkFailed.
  ///
  /// In ko, this message translates to:
  /// **'{provider} 계정 연동 해제에 실패했습니다.'**
  String error_unlinkFailed(String provider);

  /// No description provided for @snackbar_codeResent.
  ///
  /// In ko, this message translates to:
  /// **'코드가 다시 전송되었습니다.'**
  String get snackbar_codeResent;

  /// No description provided for @snackbar_passwordChanged.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호가 성공적으로 변경되었습니다.'**
  String get snackbar_passwordChanged;

  /// No description provided for @snackbar_saved.
  ///
  /// In ko, this message translates to:
  /// **'저장되었습니다.'**
  String get snackbar_saved;

  /// No description provided for @snackbar_updated.
  ///
  /// In ko, this message translates to:
  /// **'수정되었습니다.'**
  String get snackbar_updated;

  /// No description provided for @snackbar_registered.
  ///
  /// In ko, this message translates to:
  /// **'등록되었습니다.'**
  String get snackbar_registered;

  /// No description provided for @snackbar_deleted.
  ///
  /// In ko, this message translates to:
  /// **'삭제되었습니다.'**
  String get snackbar_deleted;

  /// No description provided for @snackbar_googleLinked.
  ///
  /// In ko, this message translates to:
  /// **'Google 계정이 연동되었습니다.'**
  String get snackbar_googleLinked;

  /// No description provided for @snackbar_appleLinked.
  ///
  /// In ko, this message translates to:
  /// **'Apple 계정이 연동되었습니다.'**
  String get snackbar_appleLinked;

  /// No description provided for @snackbar_kakaoLinked.
  ///
  /// In ko, this message translates to:
  /// **'카카오 계정이 연동되었습니다.'**
  String get snackbar_kakaoLinked;

  /// No description provided for @snackbar_unlinked.
  ///
  /// In ko, this message translates to:
  /// **'{provider} 계정 연동이 해제되었습니다.'**
  String snackbar_unlinked(String provider);

  /// No description provided for @validation_enterEmail.
  ///
  /// In ko, this message translates to:
  /// **'이메일을 입력해 주세요.'**
  String get validation_enterEmail;

  /// No description provided for @validation_invalidEmail.
  ///
  /// In ko, this message translates to:
  /// **'올바른 이메일 형식을 입력해 주세요.'**
  String get validation_invalidEmail;

  /// No description provided for @validation_enterPassword.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호를 입력해 주세요.'**
  String get validation_enterPassword;

  /// No description provided for @validation_passwordMin8.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호는 8자 이상이어야 합니다'**
  String get validation_passwordMin8;

  /// No description provided for @validation_enterName.
  ///
  /// In ko, this message translates to:
  /// **'이름을 입력해 주세요'**
  String get validation_enterName;

  /// No description provided for @validation_checkInput.
  ///
  /// In ko, this message translates to:
  /// **'입력 정보를 확인해 주세요'**
  String get validation_checkInput;

  /// No description provided for @validation_enterNewPassword.
  ///
  /// In ko, this message translates to:
  /// **'새로운 비밀번호를 입력해 주세요.'**
  String get validation_enterNewPassword;

  /// No description provided for @validation_confirmPassword.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호를 다시 입력해 주세요.'**
  String get validation_confirmPassword;

  /// No description provided for @validation_passwordMismatch.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호가 일치하지 않습니다.'**
  String get validation_passwordMismatch;

  /// No description provided for @datetime_weekday_mon.
  ///
  /// In ko, this message translates to:
  /// **'월'**
  String get datetime_weekday_mon;

  /// No description provided for @datetime_weekday_tue.
  ///
  /// In ko, this message translates to:
  /// **'화'**
  String get datetime_weekday_tue;

  /// No description provided for @datetime_weekday_wed.
  ///
  /// In ko, this message translates to:
  /// **'수'**
  String get datetime_weekday_wed;

  /// No description provided for @datetime_weekday_thu.
  ///
  /// In ko, this message translates to:
  /// **'목'**
  String get datetime_weekday_thu;

  /// No description provided for @datetime_weekday_fri.
  ///
  /// In ko, this message translates to:
  /// **'금'**
  String get datetime_weekday_fri;

  /// No description provided for @datetime_weekday_sat.
  ///
  /// In ko, this message translates to:
  /// **'토'**
  String get datetime_weekday_sat;

  /// No description provided for @datetime_weekday_sun.
  ///
  /// In ko, this message translates to:
  /// **'일'**
  String get datetime_weekday_sun;

  /// No description provided for @datetime_dateFormat.
  ///
  /// In ko, this message translates to:
  /// **'{year}년 {month}월 {day}일 ({weekday})'**
  String datetime_dateFormat(int year, int month, int day, String weekday);

  /// No description provided for @datetime_dateShort.
  ///
  /// In ko, this message translates to:
  /// **'{month}/{day} ({weekday})'**
  String datetime_dateShort(int month, int day, String weekday);

  /// No description provided for @social_kakao.
  ///
  /// In ko, this message translates to:
  /// **'카카오'**
  String get social_kakao;

  /// No description provided for @social_google.
  ///
  /// In ko, this message translates to:
  /// **'Google'**
  String get social_google;

  /// No description provided for @social_apple.
  ///
  /// In ko, this message translates to:
  /// **'Apple'**
  String get social_apple;

  /// No description provided for @profile_user.
  ///
  /// In ko, this message translates to:
  /// **'사용자'**
  String get profile_user;

  /// No description provided for @profile_userSuffix.
  ///
  /// In ko, this message translates to:
  /// **'님'**
  String get profile_userSuffix;

  /// No description provided for @profile_languageSettings.
  ///
  /// In ko, this message translates to:
  /// **'언어 설정'**
  String get profile_languageSettings;

  /// No description provided for @profile_languageSelect.
  ///
  /// In ko, this message translates to:
  /// **'언어 선택'**
  String get profile_languageSelect;

  /// No description provided for @profile_deviceDefault.
  ///
  /// In ko, this message translates to:
  /// **'기기 설정'**
  String get profile_deviceDefault;

  /// No description provided for @profile_deviceDefaultSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'시스템 언어를 따릅니다'**
  String get profile_deviceDefaultSubtitle;

  /// No description provided for @profile_zeroDay.
  ///
  /// In ko, this message translates to:
  /// **'0일'**
  String get profile_zeroDay;

  /// No description provided for @bhi_title.
  ///
  /// In ko, this message translates to:
  /// **'건강 점수'**
  String get bhi_title;

  /// No description provided for @bhi_noDataTitle.
  ///
  /// In ko, this message translates to:
  /// **'건강 데이터가 아직 없습니다'**
  String get bhi_noDataTitle;

  /// No description provided for @bhi_noDataSubtitle.
  ///
  /// In ko, this message translates to:
  /// **'체중, 사료, 수분 데이터를 입력해주세요'**
  String get bhi_noDataSubtitle;

  /// No description provided for @bhi_scoreComposition.
  ///
  /// In ko, this message translates to:
  /// **'점수 구성'**
  String get bhi_scoreComposition;

  /// No description provided for @bhi_healthScore.
  ///
  /// In ko, this message translates to:
  /// **'BHI 건강 점수'**
  String get bhi_healthScore;

  /// No description provided for @bhi_scoreMax.
  ///
  /// In ko, this message translates to:
  /// **'/100'**
  String get bhi_scoreMax;

  /// No description provided for @bhi_noData.
  ///
  /// In ko, this message translates to:
  /// **'데이터 없음'**
  String get bhi_noData;

  /// No description provided for @bhi_wciLevel.
  ///
  /// In ko, this message translates to:
  /// **'WCI 레벨'**
  String get bhi_wciLevel;

  /// No description provided for @bhi_growthStage.
  ///
  /// In ko, this message translates to:
  /// **'성장 단계'**
  String get bhi_growthStage;

  /// No description provided for @bhi_stageNumber.
  ///
  /// In ko, this message translates to:
  /// **'{stage}단계'**
  String bhi_stageNumber(int stage);

  /// No description provided for @bhi_accuracyHint.
  ///
  /// In ko, this message translates to:
  /// **'기록을 오래 할수록 더 정확한 건강 점수를 확인할 수 있어요.'**
  String get bhi_accuracyHint;

  /// No description provided for @bhi_baseDate.
  ///
  /// In ko, this message translates to:
  /// **'기준 날짜: {date}'**
  String bhi_baseDate(String date);

  /// No description provided for @bhi_statusHealthy.
  ///
  /// In ko, this message translates to:
  /// **'건강한 상태'**
  String get bhi_statusHealthy;

  /// No description provided for @bhi_statusStable.
  ///
  /// In ko, this message translates to:
  /// **'안정적인 상태'**
  String get bhi_statusStable;

  /// No description provided for @bhi_statusCaution.
  ///
  /// In ko, this message translates to:
  /// **'주의가 필요해요'**
  String get bhi_statusCaution;

  /// No description provided for @bhi_statusManagement.
  ///
  /// In ko, this message translates to:
  /// **'관리가 필요해요'**
  String get bhi_statusManagement;

  /// No description provided for @bhi_statusInsufficient.
  ///
  /// In ko, this message translates to:
  /// **'데이터 부족'**
  String get bhi_statusInsufficient;

  /// No description provided for @bhi_descHealthy.
  ///
  /// In ko, this message translates to:
  /// **'체중, 식사, 수분 모두 양호합니다.\n지금 습관을 유지해 주세요.'**
  String get bhi_descHealthy;

  /// No description provided for @bhi_descStable.
  ///
  /// In ko, this message translates to:
  /// **'전반적으로 괜찮지만\n일부 항목을 확인해 보세요.'**
  String get bhi_descStable;

  /// No description provided for @bhi_descCaution.
  ///
  /// In ko, this message translates to:
  /// **'몇 가지 항목에서 변화가 감지되었어요.\n데이터를 확인해 보세요.'**
  String get bhi_descCaution;

  /// No description provided for @bhi_descManagement.
  ///
  /// In ko, this message translates to:
  /// **'건강 지표가 낮은 편이에요.\n식사량과 수분을 점검해 주세요.'**
  String get bhi_descManagement;

  /// No description provided for @bhi_descInsufficient.
  ///
  /// In ko, this message translates to:
  /// **'데이터를 입력하면 건강 점수를 확인할 수 있어요.'**
  String get bhi_descInsufficient;

  /// No description provided for @bhi_growthAdult.
  ///
  /// In ko, this message translates to:
  /// **'성체 (청년기)'**
  String get bhi_growthAdult;

  /// No description provided for @bhi_growthPostGrowth.
  ///
  /// In ko, this message translates to:
  /// **'후속 성장기'**
  String get bhi_growthPostGrowth;

  /// No description provided for @bhi_growthRapidGrowth.
  ///
  /// In ko, this message translates to:
  /// **'빠른 성장기'**
  String get bhi_growthRapidGrowth;

  /// No description provided for @food_title.
  ///
  /// In ko, this message translates to:
  /// **'사료'**
  String get food_title;

  /// No description provided for @food_addTitle.
  ///
  /// In ko, this message translates to:
  /// **'사료 추가'**
  String get food_addTitle;

  /// No description provided for @food_editTitle.
  ///
  /// In ko, this message translates to:
  /// **'사료 수정'**
  String get food_editTitle;

  /// No description provided for @food_nameLabel.
  ///
  /// In ko, this message translates to:
  /// **'사료 이름'**
  String get food_nameLabel;

  /// No description provided for @food_totalIntake.
  ///
  /// In ko, this message translates to:
  /// **'총 섭취량(g)'**
  String get food_totalIntake;

  /// No description provided for @food_targetAmount.
  ///
  /// In ko, this message translates to:
  /// **'목표 사료량(g)'**
  String get food_targetAmount;

  /// No description provided for @food_intakeCount.
  ///
  /// In ko, this message translates to:
  /// **'섭취 횟수(회)'**
  String get food_intakeCount;

  /// No description provided for @food_routine.
  ///
  /// In ko, this message translates to:
  /// **'사료 섭취 루틴'**
  String get food_routine;

  /// No description provided for @food_addFood.
  ///
  /// In ko, this message translates to:
  /// **'취식 중인 음식 등록하기'**
  String get food_addFood;

  /// No description provided for @food_dailyTarget.
  ///
  /// In ko, this message translates to:
  /// **'1일 목표 사료량'**
  String get food_dailyTarget;

  /// No description provided for @food_recommendedRange.
  ///
  /// In ko, this message translates to:
  /// **'권장 사료량: {min}~{max}g/일'**
  String food_recommendedRange(int min, int max);

  /// No description provided for @food_dailyCount.
  ///
  /// In ko, this message translates to:
  /// **'1일 섭취 횟수'**
  String get food_dailyCount;

  /// No description provided for @food_perMeal.
  ///
  /// In ko, this message translates to:
  /// **'1회 당: {amount}g씩'**
  String food_perMeal(int amount);

  /// No description provided for @food_timesCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}회'**
  String food_timesCount(int count);

  /// No description provided for @pet_defaultName.
  ///
  /// In ko, this message translates to:
  /// **'새'**
  String get pet_defaultName;

  /// No description provided for @wciIndex_title.
  ///
  /// In ko, this message translates to:
  /// **'WCI 지수란?'**
  String get wciIndex_title;

  /// No description provided for @wciIndex_description.
  ///
  /// In ko, this message translates to:
  /// **'섭취 습관의 변화가 체중에 어떤 영향을 주고 있는지를\n백분율로 보여주는 건강 지표입니다.'**
  String get wciIndex_description;

  /// No description provided for @wciIndex_calculationMethod.
  ///
  /// In ko, this message translates to:
  /// **'계산 방법'**
  String get wciIndex_calculationMethod;

  /// No description provided for @wciIndex_levelCriteria.
  ///
  /// In ko, this message translates to:
  /// **'WCI 5단계 기준'**
  String get wciIndex_levelCriteria;

  /// No description provided for @chatbot_title.
  ///
  /// In ko, this message translates to:
  /// **'챗봇'**
  String get chatbot_title;

  /// No description provided for @chatbot_clearHistory.
  ///
  /// In ko, this message translates to:
  /// **'대화 내역 삭제'**
  String get chatbot_clearHistory;

  /// No description provided for @chatbot_clearHistoryConfirm.
  ///
  /// In ko, this message translates to:
  /// **'모든 대화 내역이 삭제됩니다. 계속하시겠습니까?'**
  String get chatbot_clearHistoryConfirm;

  /// No description provided for @chatbot_historyCleared.
  ///
  /// In ko, this message translates to:
  /// **'대화 내역이 삭제되었습니다.'**
  String get chatbot_historyCleared;

  /// No description provided for @chatbot_welcomeTitle.
  ///
  /// In ko, this message translates to:
  /// **'안녕하세요! 앵박사입니다!'**
  String get chatbot_welcomeTitle;

  /// No description provided for @chatbot_welcomeDescription.
  ///
  /// In ko, this message translates to:
  /// **'앵무새에 대해 궁금한 점이 있다면\n무엇이든 물어보세요!'**
  String get chatbot_welcomeDescription;

  /// No description provided for @chatbot_preparingAnswer.
  ///
  /// In ko, this message translates to:
  /// **'답변을 준비하고 있어요...'**
  String get chatbot_preparingAnswer;

  /// No description provided for @chatbot_aiError.
  ///
  /// In ko, this message translates to:
  /// **'AI 응답에 실패했어요. 잠시 후 다시 시도해 주세요.'**
  String get chatbot_aiError;

  /// No description provided for @chatbot_inputHint.
  ///
  /// In ko, this message translates to:
  /// **'궁금한 점을 입력하세요'**
  String get chatbot_inputHint;

  /// No description provided for @chatbot_suggestion1.
  ///
  /// In ko, this message translates to:
  /// **'초기 비타민 섭취량'**
  String get chatbot_suggestion1;

  /// No description provided for @chatbot_suggestion2.
  ///
  /// In ko, this message translates to:
  /// **'털 갈이 때 돌봄 방법'**
  String get chatbot_suggestion2;

  /// No description provided for @chatbot_suggestion3.
  ///
  /// In ko, this message translates to:
  /// **'건강검진 주기 추천'**
  String get chatbot_suggestion3;

  /// No description provided for @chatbot_suggestion4.
  ///
  /// In ko, this message translates to:
  /// **'체중 기록 팁'**
  String get chatbot_suggestion4;

  /// No description provided for @chatbot_aiCallFailed.
  ///
  /// In ko, this message translates to:
  /// **'AI 호출 실패: {error}'**
  String chatbot_aiCallFailed(String error);

  /// No description provided for @water_title.
  ///
  /// In ko, this message translates to:
  /// **'수분'**
  String get water_title;

  /// No description provided for @water_inputTitle.
  ///
  /// In ko, this message translates to:
  /// **'음수량 입력'**
  String get water_inputTitle;

  /// No description provided for @water_totalIntake.
  ///
  /// In ko, this message translates to:
  /// **'총 음수량(ml)'**
  String get water_totalIntake;

  /// No description provided for @water_intakeCount.
  ///
  /// In ko, this message translates to:
  /// **'섭취 횟수(회)'**
  String get water_intakeCount;

  /// No description provided for @water_routine.
  ///
  /// In ko, this message translates to:
  /// **'수분 섭취 루틴'**
  String get water_routine;

  /// No description provided for @water_water.
  ///
  /// In ko, this message translates to:
  /// **'물'**
  String get water_water;

  /// No description provided for @water_dailyTarget.
  ///
  /// In ko, this message translates to:
  /// **'1일 목표 음수량'**
  String get water_dailyTarget;

  /// No description provided for @water_recommendedRange.
  ///
  /// In ko, this message translates to:
  /// **'권장 음수량: {amount}ml/일'**
  String water_recommendedRange(String amount);

  /// No description provided for @water_dailyCount.
  ///
  /// In ko, this message translates to:
  /// **'1일 섭취 횟수'**
  String get water_dailyCount;

  /// No description provided for @water_perDrink.
  ///
  /// In ko, this message translates to:
  /// **'1회 당: {amount}ml씩'**
  String water_perDrink(String amount);

  /// No description provided for @water_timesCount.
  ///
  /// In ko, this message translates to:
  /// **'{count}회'**
  String water_timesCount(int count);

  /// No description provided for @weight_bodyWeight.
  ///
  /// In ko, this message translates to:
  /// **'몸무게*'**
  String get weight_bodyWeight;

  /// No description provided for @weight_addStickerHint.
  ///
  /// In ko, this message translates to:
  /// **'여기를 눌러 스티커를 추가해 보세요.'**
  String get weight_addStickerHint;

  /// No description provided for @weight_inputLabel.
  ///
  /// In ko, this message translates to:
  /// **'체중 입력 (g)'**
  String get weight_inputLabel;

  /// No description provided for @weight_recordSuccess.
  ///
  /// In ko, this message translates to:
  /// **'오늘의 체중이 기록되었습니다!'**
  String get weight_recordSuccess;

  /// No description provided for @weight_bcs1.
  ///
  /// In ko, this message translates to:
  /// **'뼈가 쉽게 만져지고 옆에서 봐도 매우 마른 모습이에요.\n조금 더 영양을 챙겨 주세요.'**
  String get weight_bcs1;

  /// No description provided for @weight_bcs2.
  ///
  /// In ko, this message translates to:
  /// **'갈비뼈가 잘 느껴지고 얇은 실루엣입니다.\n체중이 낮아진 편이라 조금 더 먹이를 늘려 주세요.'**
  String get weight_bcs2;

  /// No description provided for @weight_bcs3.
  ///
  /// In ko, this message translates to:
  /// **'갈비뼈가 보이진 않지만 살짝 만지면 쉽게 느껴져요.\n옆에서 봤을 때 배가 쑥 들어간 부분이 보여요.'**
  String get weight_bcs3;

  /// No description provided for @weight_bcs4.
  ///
  /// In ko, this message translates to:
  /// **'갈비뼈가 만져지지만 살짝 지방층이 느껴져요.\n옆모습이 둥글게 보이고 체중이 살짝 늘었어요.'**
  String get weight_bcs4;

  /// No description provided for @weight_bcs5.
  ///
  /// In ko, this message translates to:
  /// **'갈비뼈가 잘 만져지지 않고 옆모습이 동그랗게 보입니다.\n먹이량을 줄이고 활동량을 늘려 주세요.'**
  String get weight_bcs5;

  /// No description provided for @validation_enterWeight.
  ///
  /// In ko, this message translates to:
  /// **'체중을 입력해주세요.'**
  String get validation_enterWeight;

  /// No description provided for @validation_enterValidNumber.
  ///
  /// In ko, this message translates to:
  /// **'올바른 숫자를 입력해주세요.'**
  String get validation_enterValidNumber;

  /// No description provided for @validation_weightGreaterThanZero.
  ///
  /// In ko, this message translates to:
  /// **'체중은 0보다 커야 합니다.'**
  String get validation_weightGreaterThanZero;

  /// No description provided for @error_noPetFound.
  ///
  /// In ko, this message translates to:
  /// **'활성 펫을 찾을 수 없습니다.'**
  String get error_noPetFound;

  /// No description provided for @datetime_lunar.
  ///
  /// In ko, this message translates to:
  /// **'음력 {month}월 {day}일'**
  String datetime_lunar(int month, int day);

  /// No description provided for @datetime_weekdayFull_sun.
  ///
  /// In ko, this message translates to:
  /// **'일요일'**
  String get datetime_weekdayFull_sun;

  /// No description provided for @datetime_weekdayFull_mon.
  ///
  /// In ko, this message translates to:
  /// **'월요일'**
  String get datetime_weekdayFull_mon;

  /// No description provided for @datetime_weekdayFull_tue.
  ///
  /// In ko, this message translates to:
  /// **'화요일'**
  String get datetime_weekdayFull_tue;

  /// No description provided for @datetime_weekdayFull_wed.
  ///
  /// In ko, this message translates to:
  /// **'수요일'**
  String get datetime_weekdayFull_wed;

  /// No description provided for @datetime_weekdayFull_thu.
  ///
  /// In ko, this message translates to:
  /// **'목요일'**
  String get datetime_weekdayFull_thu;

  /// No description provided for @datetime_weekdayFull_fri.
  ///
  /// In ko, this message translates to:
  /// **'금요일'**
  String get datetime_weekdayFull_fri;

  /// No description provided for @datetime_weekdayFull_sat.
  ///
  /// In ko, this message translates to:
  /// **'토요일'**
  String get datetime_weekdayFull_sat;

  /// No description provided for @datetime_minutes.
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분'**
  String datetime_minutes(int minutes);

  /// No description provided for @datetime_seconds.
  ///
  /// In ko, this message translates to:
  /// **'{seconds}초'**
  String datetime_seconds(int seconds);

  /// No description provided for @notification_title.
  ///
  /// In ko, this message translates to:
  /// **'알림'**
  String get notification_title;

  /// No description provided for @notification_markAllRead.
  ///
  /// In ko, this message translates to:
  /// **'모두 읽음'**
  String get notification_markAllRead;

  /// No description provided for @notification_empty.
  ///
  /// In ko, this message translates to:
  /// **'알림이 없습니다'**
  String get notification_empty;

  /// No description provided for @notification_deleteError.
  ///
  /// In ko, this message translates to:
  /// **'삭제 중 오류가 발생했습니다.'**
  String get notification_deleteError;

  /// No description provided for @notification_justNow.
  ///
  /// In ko, this message translates to:
  /// **'방금 전'**
  String get notification_justNow;

  /// No description provided for @notification_minutesAgo.
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분 전'**
  String notification_minutesAgo(int minutes);

  /// No description provided for @notification_hoursAgo.
  ///
  /// In ko, this message translates to:
  /// **'{hours}시간 전'**
  String notification_hoursAgo(int hours);

  /// No description provided for @notification_daysAgo.
  ///
  /// In ko, this message translates to:
  /// **'{days}일 전'**
  String notification_daysAgo(int days);

  /// No description provided for @schedule_saveError.
  ///
  /// In ko, this message translates to:
  /// **'일정 저장 중 오류가 발생했습니다.'**
  String get schedule_saveError;

  /// No description provided for @schedule_deleted.
  ///
  /// In ko, this message translates to:
  /// **'일정이 삭제되었습니다.'**
  String get schedule_deleted;

  /// No description provided for @schedule_deleteError.
  ///
  /// In ko, this message translates to:
  /// **'일정 삭제 중 오류가 발생했습니다.'**
  String get schedule_deleteError;

  /// No description provided for @schedule_reminderMinutes.
  ///
  /// In ko, this message translates to:
  /// **'{minutes}분 전'**
  String schedule_reminderMinutes(int minutes);

  /// No description provided for @btn_save.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get btn_save;

  /// No description provided for @btn_saveRecord.
  ///
  /// In ko, this message translates to:
  /// **'저장하기'**
  String get btn_saveRecord;

  /// No description provided for @error_network.
  ///
  /// In ko, this message translates to:
  /// **'네트워크 연결을 확인해 주세요.'**
  String get error_network;

  /// No description provided for @error_server.
  ///
  /// In ko, this message translates to:
  /// **'서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.'**
  String get error_server;

  /// No description provided for @error_authRequired.
  ///
  /// In ko, this message translates to:
  /// **'로그인이 필요합니다.'**
  String get error_authRequired;

  /// No description provided for @error_conflict.
  ///
  /// In ko, this message translates to:
  /// **'이미 등록된 정보가 있습니다.'**
  String get error_conflict;

  /// No description provided for @error_invalidData.
  ///
  /// In ko, this message translates to:
  /// **'입력 정보를 다시 확인해 주세요.'**
  String get error_invalidData;

  /// No description provided for @error_notFound.
  ///
  /// In ko, this message translates to:
  /// **'요청하신 정보를 찾을 수 없습니다.'**
  String get error_notFound;

  /// No description provided for @error_savePetFailed.
  ///
  /// In ko, this message translates to:
  /// **'펫 정보 저장에 실패했습니다. 다시 시도해 주세요.'**
  String get error_savePetFailed;

  /// No description provided for @error_saveWeightFailed.
  ///
  /// In ko, this message translates to:
  /// **'체중 기록 저장에 실패했습니다. 다시 시도해 주세요.'**
  String get error_saveWeightFailed;

  /// No description provided for @coach_wciCard_title.
  ///
  /// In ko, this message translates to:
  /// **'건강 상태'**
  String get coach_wciCard_title;

  /// No description provided for @coach_wciCard_body.
  ///
  /// In ko, this message translates to:
  /// **'WCI 건강 상태를 확인하세요.\n데이터가 쌓일수록 더 정확해져요!'**
  String get coach_wciCard_body;

  /// No description provided for @coach_weightCard_title.
  ///
  /// In ko, this message translates to:
  /// **'체중 기록'**
  String get coach_weightCard_title;

  /// No description provided for @coach_weightCard_body.
  ///
  /// In ko, this message translates to:
  /// **'여기서 체중을 기록해보세요!\n매일 기록하면 건강 변화를 추적할 수 있어요.'**
  String get coach_weightCard_body;

  /// No description provided for @coach_foodCard_title.
  ///
  /// In ko, this message translates to:
  /// **'사료 기록'**
  String get coach_foodCard_title;

  /// No description provided for @coach_foodCard_body.
  ///
  /// In ko, this message translates to:
  /// **'사료 취식량을 기록해보세요.\n정확한 건강 분석에 도움이 돼요.'**
  String get coach_foodCard_body;

  /// No description provided for @coach_healthSignalCard_title.
  ///
  /// In ko, this message translates to:
  /// **'오늘의 건강 신호'**
  String get coach_healthSignalCard_title;

  /// No description provided for @coach_healthSignalCard_body.
  ///
  /// In ko, this message translates to:
  /// **'AI가 분석한 건강 신호를 확인해보세요.'**
  String get coach_healthSignalCard_body;

  /// No description provided for @coach_waterCard_title.
  ///
  /// In ko, this message translates to:
  /// **'수분 기록'**
  String get coach_waterCard_title;

  /// No description provided for @coach_waterCard_body.
  ///
  /// In ko, this message translates to:
  /// **'음수량을 기록해보세요.\n수분 섭취도 건강 관리의 중요한 요소예요.'**
  String get coach_waterCard_body;

  /// No description provided for @coach_recordsTab_title.
  ///
  /// In ko, this message translates to:
  /// **'기록 탭'**
  String get coach_recordsTab_title;

  /// No description provided for @coach_recordsTab_body.
  ///
  /// In ko, this message translates to:
  /// **'여기서 체중 변화와 일정을\n한눈에 확인할 수 있어요.'**
  String get coach_recordsTab_body;

  /// No description provided for @coach_chatbotTab_title.
  ///
  /// In ko, this message translates to:
  /// **'앵박사'**
  String get coach_chatbotTab_title;

  /// No description provided for @coach_chatbotTab_body.
  ///
  /// In ko, this message translates to:
  /// **'앵무새에 대해 궁금한 점이 있다면\nAI 앵박사에게 물어보세요!'**
  String get coach_chatbotTab_body;

  /// No description provided for @coach_recordToggle_title.
  ///
  /// In ko, this message translates to:
  /// **'기간 전환'**
  String get coach_recordToggle_title;

  /// No description provided for @coach_recordToggle_body.
  ///
  /// In ko, this message translates to:
  /// **'주간/월간 버튼을 눌러 기간별 체중 변화를 확인하세요.'**
  String get coach_recordToggle_body;

  /// No description provided for @coach_recordChart_title.
  ///
  /// In ko, this message translates to:
  /// **'체중 차트'**
  String get coach_recordChart_title;

  /// No description provided for @coach_recordChart_body.
  ///
  /// In ko, this message translates to:
  /// **'차트에서 체중 추이를 한눈에 확인할 수 있어요.'**
  String get coach_recordChart_body;

  /// No description provided for @coach_recordCalendar_title.
  ///
  /// In ko, this message translates to:
  /// **'캘린더'**
  String get coach_recordCalendar_title;

  /// No description provided for @coach_recordCalendar_body.
  ///
  /// In ko, this message translates to:
  /// **'날짜를 선택하면 해당 날의 기록을 볼 수 있어요.'**
  String get coach_recordCalendar_body;

  /// No description provided for @coach_recordAddBtn_title.
  ///
  /// In ko, this message translates to:
  /// **'기록 추가'**
  String get coach_recordAddBtn_title;

  /// No description provided for @coach_recordAddBtn_body.
  ///
  /// In ko, this message translates to:
  /// **'이 버튼을 눌러 새 체중을 기록하세요.'**
  String get coach_recordAddBtn_body;

  /// No description provided for @coach_chatSuggestion_title.
  ///
  /// In ko, this message translates to:
  /// **'추천 질문'**
  String get coach_chatSuggestion_title;

  /// No description provided for @coach_chatSuggestion_body.
  ///
  /// In ko, this message translates to:
  /// **'궁금한 주제를 탭하면 바로 AI에게 물어볼 수 있어요.'**
  String get coach_chatSuggestion_body;

  /// No description provided for @coach_chatInput_title.
  ///
  /// In ko, this message translates to:
  /// **'질문 입력'**
  String get coach_chatInput_title;

  /// No description provided for @coach_chatInput_body.
  ///
  /// In ko, this message translates to:
  /// **'직접 질문을 입력해서 앵박사에게 물어보세요.'**
  String get coach_chatInput_body;

  /// No description provided for @coach_next.
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get coach_next;

  /// No description provided for @coach_gotIt.
  ///
  /// In ko, this message translates to:
  /// **'알겠어요!'**
  String get coach_gotIt;

  /// No description provided for @coach_skip.
  ///
  /// In ko, this message translates to:
  /// **'건너뛰기'**
  String get coach_skip;

  /// No description provided for @weight_selectTime.
  ///
  /// In ko, this message translates to:
  /// **'측정 시간'**
  String get weight_selectTime;

  /// No description provided for @weight_timeNotRecorded.
  ///
  /// In ko, this message translates to:
  /// **'시간 미기록'**
  String get weight_timeNotRecorded;

  /// No description provided for @weight_dailyAverage.
  ///
  /// In ko, this message translates to:
  /// **'일평균'**
  String get weight_dailyAverage;

  /// No description provided for @weight_multipleRecords.
  ///
  /// In ko, this message translates to:
  /// **'{count}회 측정'**
  String weight_multipleRecords(int count);

  /// No description provided for @weight_addAnother.
  ///
  /// In ko, this message translates to:
  /// **'추가 기록'**
  String get weight_addAnother;

  /// No description provided for @weight_deleteRecord.
  ///
  /// In ko, this message translates to:
  /// **'이 기록을 삭제하시겠습니까?'**
  String get weight_deleteRecord;

  /// No description provided for @weight_deleteConfirm.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get weight_deleteConfirm;

  /// No description provided for @weight_amPeriod.
  ///
  /// In ko, this message translates to:
  /// **'오전'**
  String get weight_amPeriod;

  /// No description provided for @weight_pmPeriod.
  ///
  /// In ko, this message translates to:
  /// **'오후'**
  String get weight_pmPeriod;

  /// No description provided for @diet_serving.
  ///
  /// In ko, this message translates to:
  /// **'배식'**
  String get diet_serving;

  /// No description provided for @diet_eating.
  ///
  /// In ko, this message translates to:
  /// **'취식'**
  String get diet_eating;

  /// No description provided for @diet_addServing.
  ///
  /// In ko, this message translates to:
  /// **'배식 기록 추가'**
  String get diet_addServing;

  /// No description provided for @diet_addEating.
  ///
  /// In ko, this message translates to:
  /// **'취식 기록 추가'**
  String get diet_addEating;

  /// No description provided for @diet_addRecord.
  ///
  /// In ko, this message translates to:
  /// **'기록 추가'**
  String get diet_addRecord;

  /// No description provided for @diet_editRecord.
  ///
  /// In ko, this message translates to:
  /// **'기록 수정'**
  String get diet_editRecord;

  /// No description provided for @diet_totalServed.
  ///
  /// In ko, this message translates to:
  /// **'총 배식량'**
  String get diet_totalServed;

  /// No description provided for @diet_totalEaten.
  ///
  /// In ko, this message translates to:
  /// **'총 취식량'**
  String get diet_totalEaten;

  /// No description provided for @diet_eatingRate.
  ///
  /// In ko, this message translates to:
  /// **'취식률'**
  String get diet_eatingRate;

  /// No description provided for @diet_eatingRateValue.
  ///
  /// In ko, this message translates to:
  /// **'{rate}%'**
  String diet_eatingRateValue(int rate);

  /// No description provided for @diet_selectTime.
  ///
  /// In ko, this message translates to:
  /// **'급여/섭취 시간'**
  String get diet_selectTime;

  /// No description provided for @diet_servingSummary.
  ///
  /// In ko, this message translates to:
  /// **'배식 {count}회 · {grams}g'**
  String diet_servingSummary(int count, String grams);

  /// No description provided for @diet_eatingSummary.
  ///
  /// In ko, this message translates to:
  /// **'취식 {count}회 · {grams}g'**
  String diet_eatingSummary(int count, String grams);

  /// No description provided for @diet_selectType.
  ///
  /// In ko, this message translates to:
  /// **'기록 유형'**
  String get diet_selectType;

  /// No description provided for @diet_foodName.
  ///
  /// In ko, this message translates to:
  /// **'음식 이름'**
  String get diet_foodName;

  /// No description provided for @diet_amount.
  ///
  /// In ko, this message translates to:
  /// **'양(g)'**
  String get diet_amount;

  /// No description provided for @diet_memo.
  ///
  /// In ko, this message translates to:
  /// **'메모 (선택)'**
  String get diet_memo;

  /// No description provided for @faq_title.
  ///
  /// In ko, this message translates to:
  /// **'자주 묻는 질문'**
  String get faq_title;

  /// No description provided for @faq_categoryGeneral.
  ///
  /// In ko, this message translates to:
  /// **'일반'**
  String get faq_categoryGeneral;

  /// No description provided for @faq_categoryUsage.
  ///
  /// In ko, this message translates to:
  /// **'기능 사용법'**
  String get faq_categoryUsage;

  /// No description provided for @faq_categoryAccount.
  ///
  /// In ko, this message translates to:
  /// **'계정 관리'**
  String get faq_categoryAccount;

  /// No description provided for @faq_categoryPet.
  ///
  /// In ko, this message translates to:
  /// **'반려동물 관리'**
  String get faq_categoryPet;

  /// No description provided for @faq_q1.
  ///
  /// In ko, this message translates to:
  /// **'이 앱은 무료인가요?'**
  String get faq_q1;

  /// No description provided for @faq_a1.
  ///
  /// In ko, this message translates to:
  /// **'네, Perch Care의 기본 기능은 모두 무료로 이용할 수 있습니다.'**
  String get faq_a1;

  /// No description provided for @faq_q2.
  ///
  /// In ko, this message translates to:
  /// **'AI 건강 분석은 얼마나 정확한가요?'**
  String get faq_q2;

  /// No description provided for @faq_a2.
  ///
  /// In ko, this message translates to:
  /// **'AI 분석은 참고용이며, 정확한 진단을 대체하지 않습니다. 반려동물의 건강에 이상이 있다면 반드시 수의사와 상담해 주세요.'**
  String get faq_a2;

  /// No description provided for @faq_q3.
  ///
  /// In ko, this message translates to:
  /// **'데이터는 안전하게 보존되나요?'**
  String get faq_q3;

  /// No description provided for @faq_a3.
  ///
  /// In ko, this message translates to:
  /// **'모든 데이터는 암호화되어 안전하게 서버에 저장됩니다. 기기를 변경하더라도 로그인하면 데이터가 복원됩니다.'**
  String get faq_a3;

  /// No description provided for @faq_q4.
  ///
  /// In ko, this message translates to:
  /// **'체중은 어떻게 기록하나요?'**
  String get faq_q4;

  /// No description provided for @faq_a4.
  ///
  /// In ko, this message translates to:
  /// **'하단 네비게이션의 체중 탭에서 날짜를 선택하고 체중(g)을 입력하면 됩니다.'**
  String get faq_a4;

  /// No description provided for @faq_q5.
  ///
  /// In ko, this message translates to:
  /// **'사료/수분 기록은 어떻게 하나요?'**
  String get faq_q5;

  /// No description provided for @faq_a5.
  ///
  /// In ko, this message translates to:
  /// **'홈 화면의 사료 또는 수분 카드를 탭하면 기록 화면으로 이동합니다. 각 항목을 추가하고 저장하세요.'**
  String get faq_a5;

  /// No description provided for @faq_q6.
  ///
  /// In ko, this message translates to:
  /// **'BHI(건강지수)는 무엇인가요?'**
  String get faq_q6;

  /// No description provided for @faq_a6.
  ///
  /// In ko, this message translates to:
  /// **'BHI(Bird Health Index)는 체중, 사료, 수분 기록을 종합하여 반려조의 건강 상태를 점수로 보여주는 지표입니다.'**
  String get faq_a6;

  /// No description provided for @faq_q7.
  ///
  /// In ko, this message translates to:
  /// **'기록을 수정하거나 삭제할 수 있나요?'**
  String get faq_q7;

  /// No description provided for @faq_a7.
  ///
  /// In ko, this message translates to:
  /// **'네, 사료 기록은 항목을 탭하면 수정할 수 있습니다. 삭제는 항목을 왼쪽으로 스와이프하면 됩니다.'**
  String get faq_a7;

  /// No description provided for @faq_q8.
  ///
  /// In ko, this message translates to:
  /// **'언어를 변경하려면 어떻게 하나요?'**
  String get faq_q8;

  /// No description provided for @faq_a8.
  ///
  /// In ko, this message translates to:
  /// **'프로필 화면의 \'언어 설정\'에서 한국어, English, 中文 중 선택할 수 있습니다.'**
  String get faq_a8;

  /// No description provided for @faq_q9.
  ///
  /// In ko, this message translates to:
  /// **'소셜 계정을 연동하거나 해제하려면?'**
  String get faq_q9;

  /// No description provided for @faq_a9.
  ///
  /// In ko, this message translates to:
  /// **'프로필 화면의 \'소셜 계정 연동\'에서 Google, Apple 계정을 연동하거나 해제할 수 있습니다.'**
  String get faq_a9;

  /// No description provided for @faq_q10.
  ///
  /// In ko, this message translates to:
  /// **'회원 탈퇴하면 데이터는 어떻게 되나요?'**
  String get faq_q10;

  /// No description provided for @faq_a10.
  ///
  /// In ko, this message translates to:
  /// **'탈퇴 시 모든 개인정보와 반려동물 기록이 영구적으로 삭제되며 복구할 수 없습니다.'**
  String get faq_a10;

  /// No description provided for @faq_q11.
  ///
  /// In ko, this message translates to:
  /// **'반려동물을 추가하거나 삭제하려면?'**
  String get faq_q11;

  /// No description provided for @faq_a11.
  ///
  /// In ko, this message translates to:
  /// **'프로필 화면의 \'나의 반려가족\'에서 (+) 버튼으로 추가하고, (X) 버튼으로 삭제할 수 있습니다.'**
  String get faq_a11;

  /// No description provided for @faq_q12.
  ///
  /// In ko, this message translates to:
  /// **'어떤 종을 지원하나요?'**
  String get faq_q12;

  /// No description provided for @faq_a12.
  ///
  /// In ko, this message translates to:
  /// **'현재 앵무새류(사랑앵무, 왕관앵무 등)를 지원하고 있으며, 다른 조류 종은 추후 지원 예정입니다.'**
  String get faq_a12;

  /// No description provided for @faq_q13.
  ///
  /// In ko, this message translates to:
  /// **'Android나 HarmonyOS도 지원하나요?'**
  String get faq_q13;

  /// No description provided for @faq_a13.
  ///
  /// In ko, this message translates to:
  /// **'현재는 iOS만 지원하고 있습니다. Android 및 HarmonyOS 버전은 개발 중이며, 추후 출시 예정입니다.'**
  String get faq_a13;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
