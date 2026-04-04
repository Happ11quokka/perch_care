// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get common_save => '저장';

  @override
  String get common_cancel => '취소';

  @override
  String get common_confirm => '확인';

  @override
  String get common_close => '닫기';

  @override
  String get common_delete => '삭제';

  @override
  String get common_edit => '수정';

  @override
  String get common_later => '나중에 하기';

  @override
  String get common_view => '보기';

  @override
  String get common_noData => '데이터가 없습니다';

  @override
  String get common_loading => '로딩 중...';

  @override
  String get common_saveSuccess => '저장되었습니다.';

  @override
  String common_saveError(String error) {
    return '저장 중 오류가 발생했습니다: $error';
  }

  @override
  String get common_updated => '수정되었습니다.';

  @override
  String get common_registered => '등록되었습니다.';

  @override
  String get common_collapse => '접기';

  @override
  String common_showAll(int count) {
    return '전체 보기 ($count건)';
  }

  @override
  String get pet_loadError => '펫 정보를 불러오는데 실패했습니다.';

  @override
  String get onboarding_title => '만나서 반가워요!';

  @override
  String get onboarding_description =>
      '단순한 기록을 넘어, AI 분석으로 앵무새의\n상태를 더 깊이 이해해 보세요.';

  @override
  String get btn_start => '시작하기';

  @override
  String get login_title => '로그인';

  @override
  String get login_google => 'Google로 로그인';

  @override
  String get login_apple => 'Apple로 로그인';

  @override
  String get login_email => '이메일로 로그인';

  @override
  String get login_button => '로그인';

  @override
  String get login_notMember => '아직 회원이 아니신가요?';

  @override
  String get login_signup => '회원가입';

  @override
  String get login_saveId => '아이디 저장';

  @override
  String get login_findIdPassword => '아이디/비밀번호 찾기';

  @override
  String get input_email => '이메일';

  @override
  String get input_email_hint => '이메일을 입력해 주세요';

  @override
  String get input_password => '비밀번호';

  @override
  String get input_password_hint => '비밀번호를 입력해 주세요';

  @override
  String get input_name => '이름';

  @override
  String get input_name_hint => '이름을 입력해 주세요';

  @override
  String get dialog_goSignup => '회원가입하기';

  @override
  String get signup_title => '가입하기';

  @override
  String get signup_button => '회원가입';

  @override
  String get signup_alreadyMember => '이미 계정이 있으신가요?';

  @override
  String get signup_completeTitle => '회원가입 완료';

  @override
  String get signup_completeMessage => '회원가입이 완료되었습니다!\n로그인 후 서비스를 이용할 수 있습니다.';

  @override
  String get terms_agreeAll => '전체 동의';

  @override
  String get terms_requiredTerms => '[필수] 이용약관 동의';

  @override
  String get terms_requiredPrivacy => '[필수] 개인정보 수집 및 이용 동의';

  @override
  String get terms_optionalMarketing => '[선택] 마케팅 정보 수신 동의';

  @override
  String get terms_termsOfService => '이용약관';

  @override
  String get terms_privacyPolicy => '개인정보처리방침';

  @override
  String get terms_marketing => '마케팅 정보 수신 동의';

  @override
  String get terms_sectionTitle => '약관 및 정책';

  @override
  String get forgot_title => '비밀번호 찾기';

  @override
  String get forgot_description =>
      '가입 시 사용한 이메일을 입력해 주세요.\n비밀번호 재설정 코드를 보내드립니다.';

  @override
  String get btn_sendCode => '코드 보내기';

  @override
  String get forgot_codeTitle => '코드 입력';

  @override
  String get forgot_codeDescription =>
      '복구 코드가 귀하에게 전달되었습니다.\n전달 받은 코드를 2분안에 입력 하시길 바랍니다.';

  @override
  String forgot_codeSentTo(String destination) {
    return '$destination(으)로 코드를 보냈습니다.';
  }

  @override
  String forgot_timeRemaining(String time) {
    return '코드 입력까지 $time 남았습니다.';
  }

  @override
  String get btn_resendCode => '코드 다시 보내기';

  @override
  String get forgot_newPasswordTitle => '새로운 비밀번호';

  @override
  String get forgot_newPasswordDescription =>
      '새로운 비밀번호를 입력해 주세요,\n이전에 사용하신 비밀번호는 사용 하실 수 없습니다.';

  @override
  String get input_newPassword => '새로운 비밀번호';

  @override
  String get input_confirmPassword => '비밀번호 재입력';

  @override
  String get password_strength_weak => '약함';

  @override
  String get password_strength_medium => '보통';

  @override
  String get password_strength_strong => '강함';

  @override
  String get btn_resetComplete => '재설정 완료';

  @override
  String get home_monthlyUnit => '매월 단위';

  @override
  String get home_weeklyUnit => '매주 단위';

  @override
  String get home_wciHealthStatus => 'WCI* 건강 상태';

  @override
  String home_updatedAgo(int minutes) {
    return '$minutes분 전에 업데이트됨';
  }

  @override
  String home_updatedHoursAgo(int hours) {
    return '$hours시간 전에 업데이트됨';
  }

  @override
  String home_updatedOnDate(int month, int day) {
    return '$month월 $day일에 업데이트됨';
  }

  @override
  String get home_noUpdateData => '데이터 없음';

  @override
  String home_enterDataPrompt(String petName) {
    return '데이터를 입력해 $petName의';
  }

  @override
  String get home_checkStatus => '상태를 확인해 보세요.';

  @override
  String home_level(int level) {
    return '$level단계';
  }

  @override
  String get home_weight => '체중';

  @override
  String get home_weightHint => '체중을 입력해주세요';

  @override
  String get home_food => '사료';

  @override
  String get home_foodHint => '취식량을 입력해주세요';

  @override
  String get home_water => '수분';

  @override
  String get home_waterHint => '음수량을 입력해주세요';

  @override
  String get home_todayHealthSignal => '오늘의';

  @override
  String get home_healthSignal => '건강 신호';

  @override
  String home_monthFormat(int month) {
    return '$month월';
  }

  @override
  String home_weekFormat(int week) {
    return '$week주';
  }

  @override
  String get wci_level1 => '몸이 가볍고 마른 인상이 강해요.\n식사량이나 컨디션을 한 번 더 살펴보는 게 좋아요.';

  @override
  String get wci_level2 =>
      '갈비뼈가 보이지는 않지만 살짝 만지면 쉽게 느껴져요.\n옆에서 봤을 때 배가 쏙 들어간 부분이 보여요.';

  @override
  String get wci_level3 => '전체적인 체형은 안정적이에요.\n지금 습관을 유지하면서 가볍게 관찰해 주세요.';

  @override
  String get wci_level4 => '몸이 전체적으로 둥글어 보여요.\n식사량과 간식을 한 번 점검해 보세요.';

  @override
  String get wci_level5 => '전체적으로 무거운 인상이 들어요.\n건강을 위해 식단과 활동을 조절하는 것이 좋아요.';

  @override
  String get weight_title => '체중';

  @override
  String get weight_wciHealthStatus => 'WCI 건강 상태';

  @override
  String get weight_inputWeight => '체중 입력';

  @override
  String get weight_inputHint => '예: 58.3';

  @override
  String get weight_formula => '계산 공식';

  @override
  String get weight_formulaText => 'WCI(%) = (현재 체중 - 기준 체중) ÷ 기준 체중 × 100';

  @override
  String get weight_calculation => '계산 과정';

  @override
  String get weight_noData => '데이터가 없습니다.';

  @override
  String get weight_level0Title => 'Level 0';

  @override
  String get weight_level0Desc => '몸무게를 입력해 주세요';

  @override
  String get weight_level1Title => 'Level 1 | 가벼운 상태';

  @override
  String get weight_level1Desc => '몸이 많이 가벼워요. 식사량과 컨디션을 점검해 주세요.';

  @override
  String get weight_level2Title => 'Level 2 | 약간 가벼운 상태';

  @override
  String get weight_level2Desc => '슬림한 편이에요. 현재 습관을 유지하며 관찰하세요.';

  @override
  String get weight_level3Title => 'Level 3 | 이상적인 상태';

  @override
  String get weight_level3Desc => '체중 균형이 가장 좋은 범위에 있어요. 현재 상태를 유지하는 것이 좋아요.';

  @override
  String get weight_level4Title => 'Level 4 | 약간 무거운 상태';

  @override
  String get weight_level4Desc => '몸이 조금 묵직해 보여요. 식사 균형을 점검해 보세요.';

  @override
  String get weight_level5Title => 'Level 5 | 무거운 상태';

  @override
  String get weight_level5Desc => '체중이 많이 늘었어요. 식단과 활동 조절이 필요해요.';

  @override
  String get weight_unitGram => 'g';

  @override
  String get weight_breedRange => '품종별 체중 범위';

  @override
  String weight_breedRangeIdeal(double min, double max) {
    return '이상적: ${min}g - ${max}g';
  }

  @override
  String weight_breedRangeFull(double min, double max) {
    return '범위: ${min}g - ${max}g';
  }

  @override
  String get breed_selectTitle => '품종 선택';

  @override
  String get breed_searchHint => '품종 검색...';

  @override
  String get breed_noBreeds => '등록된 품종이 없습니다';

  @override
  String get breed_notFound => '검색 결과가 없습니다';

  @override
  String get weightDetail_title => '기록';

  @override
  String get weightDetail_headerLine1 => '꾸준히 기록을 남기며';

  @override
  String weightDetail_headerLine2(String petName) {
    return '$petName 체중 변화를 한 눈에!';
  }

  @override
  String get weightDetail_subLine1 => '지금 바로 기록하고 우리 아이 건강 상태를';

  @override
  String get weightDetail_subLine2 => '편하게 관리해 보세요.';

  @override
  String get weightDetail_toggleWeek => '주';

  @override
  String get weightDetail_toggleMonth => '월';

  @override
  String weightDetail_recordSummary(String petName, int days) {
    return '$petName의 몸무게 총 $days일 기록 중';
  }

  @override
  String weightDetail_yearMonth(int year, int month) {
    return '$year년 $month월';
  }

  @override
  String weightDetail_monthChartLabel(int month) {
    return '$month월';
  }

  @override
  String schedule_dateDisplay(int month, int day, String weekday) {
    return '$month월 $day일 ($weekday)';
  }

  @override
  String get weightDetail_noPet => '활성화된 펫이 없습니다. 펫을 먼저 추가해주세요.';

  @override
  String get weightDetail_noSchedule => '등록된 일정이 없습니다';

  @override
  String get weightDetail_addScheduleHint => '아래 버튼을 눌러 일정을 추가해보세요';

  @override
  String get weightDetail_monthSchedule => '이번 달 일정';

  @override
  String weightDetail_dateSchedule(int month, int day) {
    return '$month월 $day일 일정';
  }

  @override
  String get weightDetail_noScheduleOnDate => '이 날에 등록된 일정이 없습니다';

  @override
  String get weightDetail_noWeightRecord => '이번 달 체중 기록이 없습니다';

  @override
  String weightDetail_monthWeightRecord(int month) {
    return '$month월 체중 기록';
  }

  @override
  String get btn_addRecord => '기록 추가';

  @override
  String get weightDetail_today => '오늘';

  @override
  String get profile_title => '프로필';

  @override
  String get profile_myPets => '나의 반려가족';

  @override
  String get profile_addNewPet => '새로운 아이 등록하기';

  @override
  String get pet_delete => '반려동물 삭제';

  @override
  String get pet_deleteConfirmTitle => '반려동물 삭제';

  @override
  String get pet_deleteConfirmMessage =>
      '이 반려동물을 삭제하시겠습니까? 체중, 사료, 수분 기록 등 모든 관련 데이터가 영구적으로 삭제됩니다.';

  @override
  String get pet_deleteConfirmButton => '삭제';

  @override
  String get profile_socialAccounts => '소셜 계정 연동';

  @override
  String get profile_link => '연동';

  @override
  String get profile_linked => '연동됨';

  @override
  String get profile_notLinked => '미연동';

  @override
  String get profile_unlink => '해제';

  @override
  String get profile_appSupport => '앱 지원';

  @override
  String get profile_rateApp => '앱 평가하기';

  @override
  String get profile_accountManagement => '계정 관리';

  @override
  String get profile_logout => '로그아웃';

  @override
  String get profile_deleteAccount => '회원 탈퇴';

  @override
  String get profile_noSpecies => '종 정보 없음';

  @override
  String get profile_noAge => '나이 정보 없음';

  @override
  String profile_ageFormat(int years, int months, int days) {
    return '$years년 $months개월 $days일';
  }

  @override
  String get dialog_unlinkTitle => '소셜 계정 연동 해제';

  @override
  String dialog_unlinkContent(String provider) {
    return '$provider 계정 연동을 해제하시겠습니까?';
  }

  @override
  String get dialog_logoutTitle => '로그아웃';

  @override
  String get dialog_logoutContent => '로그아웃 하시겠습니까?';

  @override
  String get dialog_deleteAccountTitle => '회원 탈퇴';

  @override
  String get dialog_deleteAccountContent =>
      '탈퇴하시면 체중, 사료, 수분, 건강체크 등 기록된 모든 데이터가 영구적으로 삭제되며 복구할 수 없습니다.';

  @override
  String get dialog_deleteAccountFinalTitle => '정말 탈퇴하시겠습니까?';

  @override
  String get dialog_deleteAccountFinalContent => '이 작업은 되돌릴 수 없습니다.';

  @override
  String get dialog_delete => '탈퇴';

  @override
  String get pet_profile => '프로필';

  @override
  String get pet_name_hint => '이름을 입력해 주세요';

  @override
  String get pet_gender_hint => '성별을 선택해 주세요';

  @override
  String get pet_weight_hint => '몸무게';

  @override
  String get pet_birthday_hint => '생일';

  @override
  String get pet_adoptionDate_hint => '가족이 된 날';

  @override
  String get pet_species_hint => '종';

  @override
  String get pet_growthStage_hint => '성장 단계를 선택해 주세요';

  @override
  String get pet_genderMale => '수컷';

  @override
  String get pet_genderFemale => '암컷';

  @override
  String get pet_genderUnknown => '모름';

  @override
  String get pet_growthRapid => '빠른성장';

  @override
  String get pet_growthPost => '후속성장';

  @override
  String get pet_growthAdult => '청년';

  @override
  String get dialog_selectGender => '성별 선택';

  @override
  String get dialog_selectGrowthStage => '성장 단계 선택';

  @override
  String get error_googleLogin => 'Google 로그인 중 오류가 발생했습니다.';

  @override
  String get error_appleLogin => 'Apple 로그인 중 오류가 발생했습니다.';

  @override
  String get error_login => '로그인 중 오류가 발생했습니다.';

  @override
  String get error_loginRetry => '로그인 중 오류가 발생했습니다. 다시 시도해주세요.';

  @override
  String get error_sendCode => '코드 전송 중 오류가 발생했습니다.';

  @override
  String get error_invalidCode => '코드가 올바르지 않습니다. 다시 확인해 주세요.';

  @override
  String get error_passwordChange => '비밀번호 변경 중 오류가 발생했습니다.';

  @override
  String get error_unexpected => '예상치 못한 오류가 발생했습니다. 다시 시도해 주세요.';

  @override
  String error_saveFailed(String error) {
    return '저장 중 오류가 발생했습니다: $error';
  }

  @override
  String get error_loadPet => '펫 정보를 불러오는데 실패했습니다.';

  @override
  String get error_deleteAccount => '회원 탈퇴에 실패했습니다. 다시 시도해주세요.';

  @override
  String get error_linkGoogle => 'Google 계정 연동에 실패했습니다.';

  @override
  String get error_linkApple => 'Apple 계정 연동에 실패했습니다.';

  @override
  String error_unlinkFailed(String provider) {
    return '$provider 계정 연동 해제에 실패했습니다.';
  }

  @override
  String get snackbar_codeResent => '코드가 다시 전송되었습니다.';

  @override
  String get snackbar_passwordChanged => '비밀번호가 성공적으로 변경되었습니다.';

  @override
  String get snackbar_saved => '저장되었습니다.';

  @override
  String get snackbar_updated => '수정되었습니다.';

  @override
  String get snackbar_registered => '등록되었습니다.';

  @override
  String get snackbar_deleted => '삭제되었습니다.';

  @override
  String get snackbar_googleLinked => 'Google 계정이 연동되었습니다.';

  @override
  String get snackbar_appleLinked => 'Apple 계정이 연동되었습니다.';

  @override
  String snackbar_unlinked(String provider) {
    return '$provider 계정 연동이 해제되었습니다.';
  }

  @override
  String get validation_enterEmail => '이메일을 입력해 주세요.';

  @override
  String get validation_invalidEmail => '올바른 이메일 형식을 입력해 주세요.';

  @override
  String get validation_enterPassword => '비밀번호를 입력해 주세요.';

  @override
  String get validation_passwordMin8 => '비밀번호는 8자 이상이어야 합니다';

  @override
  String get validation_enterName => '이름을 입력해 주세요';

  @override
  String get validation_checkInput => '입력 정보를 확인해 주세요';

  @override
  String get validation_enterNewPassword => '새로운 비밀번호를 입력해 주세요.';

  @override
  String get validation_confirmPassword => '비밀번호를 다시 입력해 주세요.';

  @override
  String get validation_passwordMismatch => '비밀번호가 일치하지 않습니다.';

  @override
  String get datetime_weekday_mon => '월';

  @override
  String get datetime_weekday_tue => '화';

  @override
  String get datetime_weekday_wed => '수';

  @override
  String get datetime_weekday_thu => '목';

  @override
  String get datetime_weekday_fri => '금';

  @override
  String get datetime_weekday_sat => '토';

  @override
  String get datetime_weekday_sun => '일';

  @override
  String datetime_dateFormat(int year, int month, int day, String weekday) {
    return '$year년 $month월 $day일 ($weekday)';
  }

  @override
  String datetime_dateShort(int month, int day, String weekday) {
    return '$month/$day ($weekday)';
  }

  @override
  String get social_google => 'Google';

  @override
  String get social_apple => 'Apple';

  @override
  String get profile_user => '사용자';

  @override
  String get profile_userSuffix => '님';

  @override
  String get profile_languageSettings => '언어 설정';

  @override
  String get profile_languageSelect => '언어 선택';

  @override
  String get profile_deviceDefault => '기기 설정';

  @override
  String get profile_deviceDefaultSubtitle => '시스템 언어를 따릅니다';

  @override
  String get profile_zeroDay => '0일';

  @override
  String get bhi_title => '건강 점수';

  @override
  String get bhi_noDataTitle => '건강 데이터가 아직 없습니다';

  @override
  String get bhi_noDataSubtitle => '체중, 사료, 수분 데이터를 입력해주세요';

  @override
  String get bhi_scoreComposition => '점수 구성';

  @override
  String get bhi_healthScore => 'BHI 건강 점수';

  @override
  String get bhi_scoreMax => '/100';

  @override
  String get bhi_noData => '데이터 없음';

  @override
  String get bhi_wciLevel => 'WCI 레벨';

  @override
  String get bhi_growthStage => '성장 단계';

  @override
  String bhi_stageNumber(int stage) {
    return '$stage단계';
  }

  @override
  String get bhi_accuracyHint => '기록을 오래 할수록 더 정확한 건강 점수를 확인할 수 있어요.';

  @override
  String bhi_baseDate(String date) {
    return '기준 날짜: $date';
  }

  @override
  String get bhi_statusHealthy => '건강한 상태';

  @override
  String get bhi_statusStable => '안정적인 상태';

  @override
  String get bhi_statusCaution => '주의가 필요해요';

  @override
  String get bhi_statusManagement => '관리가 필요해요';

  @override
  String get bhi_statusInsufficient => '데이터 부족';

  @override
  String get bhi_descHealthy => '체중, 식사, 수분 모두 양호합니다.\n지금 습관을 유지해 주세요.';

  @override
  String get bhi_descStable => '전반적으로 괜찮지만\n일부 항목을 확인해 보세요.';

  @override
  String get bhi_descCaution => '몇 가지 항목에서 변화가 감지되었어요.\n데이터를 확인해 보세요.';

  @override
  String get bhi_descManagement => '건강 지표가 낮은 편이에요.\n식사량과 수분을 점검해 주세요.';

  @override
  String get bhi_descInsufficient => '데이터를 입력하면 건강 점수를 확인할 수 있어요.';

  @override
  String get bhi_growthAdult => '성체 (청년기)';

  @override
  String get bhi_growthPostGrowth => '후속 성장기';

  @override
  String get bhi_growthRapidGrowth => '빠른 성장기';

  @override
  String get food_title => '사료';

  @override
  String get food_addTitle => '사료 추가';

  @override
  String get food_editTitle => '사료 수정';

  @override
  String get food_nameLabel => '사료 이름';

  @override
  String get food_totalIntake => '총 섭취량(g)';

  @override
  String get food_targetAmount => '목표 사료량(g)';

  @override
  String get food_intakeCount => '섭취 횟수(회)';

  @override
  String get food_routine => '사료 섭취 루틴';

  @override
  String get food_addFood => '취식 중인 음식 등록하기';

  @override
  String get food_dailyTarget => '1일 목표 사료량';

  @override
  String food_recommendedRange(int min, int max) {
    return '권장 사료량: $min~${max}g/일';
  }

  @override
  String get food_dailyCount => '1일 섭취 횟수';

  @override
  String food_perMeal(int amount) {
    return '1회 당: ${amount}g씩';
  }

  @override
  String food_timesCount(int count) {
    return '$count회';
  }

  @override
  String get pet_defaultName => '새';

  @override
  String get wciIndex_title => 'WCI 지수란?';

  @override
  String get wciIndex_description =>
      '섭취 습관의 변화가 체중에 어떤 영향을 주고 있는지를\n백분율로 보여주는 건강 지표입니다.';

  @override
  String get wciIndex_calculationMethod => '계산 방법';

  @override
  String get wciIndex_levelCriteria => 'WCI 5단계 기준';

  @override
  String get chatbot_title => '챗봇';

  @override
  String get chatbot_clearHistory => '대화 내역 삭제';

  @override
  String get chatbot_clearHistoryConfirm => '모든 대화 내역이 삭제됩니다. 계속하시겠습니까?';

  @override
  String get chatbot_historyCleared => '대화 내역이 삭제되었습니다.';

  @override
  String get chatbot_welcomeTitle => '안녕하세요! 앵박사입니다!';

  @override
  String get chatbot_welcomeDescription => '앵무새에 대해 궁금한 점이 있다면\n무엇이든 물어보세요!';

  @override
  String get chatbot_preparingAnswer => '답변을 준비하고 있어요...';

  @override
  String get chatbot_aiError => 'AI 응답에 실패했어요. 잠시 후 다시 시도해 주세요.';

  @override
  String get chatbot_inputHint => '궁금한 점을 입력하세요';

  @override
  String get chatbot_suggestion1 => '초기 비타민 섭취량';

  @override
  String get chatbot_suggestion2 => '털 갈이 때 돌봄 방법';

  @override
  String get chatbot_suggestion3 => '건강검진 주기 추천';

  @override
  String get chatbot_suggestion4 => '체중 기록 팁';

  @override
  String chatbot_aiCallFailed(String error) {
    return 'AI 호출 실패: $error';
  }

  @override
  String get water_title => '수분';

  @override
  String get water_inputTitle => '음수량 입력';

  @override
  String get water_totalIntake => '총 음수량(ml)';

  @override
  String get water_intakeCount => '섭취 횟수(회)';

  @override
  String get water_routine => '수분 섭취 루틴';

  @override
  String get water_water => '물';

  @override
  String get water_dailyTarget => '1일 목표 음수량';

  @override
  String water_recommendedRange(String amount) {
    return '권장 음수량: ${amount}ml/일';
  }

  @override
  String get water_dailyCount => '1일 섭취 횟수';

  @override
  String water_perDrink(String amount) {
    return '1회 당: ${amount}ml씩';
  }

  @override
  String water_timesCount(int count) {
    return '$count회';
  }

  @override
  String get water_tapToInput => '탭하여 입력';

  @override
  String get water_tapToEdit => '탭하여 수정';

  @override
  String get weight_bodyWeight => '몸무게*';

  @override
  String get weight_addStickerHint => '여기를 눌러 스티커를 추가해 보세요.';

  @override
  String get weight_inputLabel => '체중 입력 (g)';

  @override
  String get weight_recordSuccess => '오늘의 체중이 기록되었습니다!';

  @override
  String get weight_bcs1 => '뼈가 쉽게 만져지고 옆에서 봐도 매우 마른 모습이에요.\n조금 더 영양을 챙겨 주세요.';

  @override
  String get weight_bcs2 =>
      '갈비뼈가 잘 느껴지고 얇은 실루엣입니다.\n체중이 낮아진 편이라 조금 더 먹이를 늘려 주세요.';

  @override
  String get weight_bcs3 =>
      '갈비뼈가 보이진 않지만 살짝 만지면 쉽게 느껴져요.\n옆에서 봤을 때 배가 쑥 들어간 부분이 보여요.';

  @override
  String get weight_bcs4 =>
      '갈비뼈가 만져지지만 살짝 지방층이 느껴져요.\n옆모습이 둥글게 보이고 체중이 살짝 늘었어요.';

  @override
  String get weight_bcs5 =>
      '갈비뼈가 잘 만져지지 않고 옆모습이 동그랗게 보입니다.\n먹이량을 줄이고 활동량을 늘려 주세요.';

  @override
  String get validation_enterWeight => '체중을 입력해주세요.';

  @override
  String get validation_enterValidNumber => '올바른 숫자를 입력해주세요.';

  @override
  String get validation_weightGreaterThanZero => '체중은 0보다 커야 합니다.';

  @override
  String get error_noPetFound => '활성 펫을 찾을 수 없습니다.';

  @override
  String datetime_lunar(int month, int day) {
    return '음력 $month월 $day일';
  }

  @override
  String get datetime_weekdayFull_sun => '일요일';

  @override
  String get datetime_weekdayFull_mon => '월요일';

  @override
  String get datetime_weekdayFull_tue => '화요일';

  @override
  String get datetime_weekdayFull_wed => '수요일';

  @override
  String get datetime_weekdayFull_thu => '목요일';

  @override
  String get datetime_weekdayFull_fri => '금요일';

  @override
  String get datetime_weekdayFull_sat => '토요일';

  @override
  String datetime_minutes(int minutes) {
    return '$minutes분';
  }

  @override
  String datetime_seconds(int seconds) {
    return '$seconds초';
  }

  @override
  String get notification_title => '알림';

  @override
  String get notification_markAllRead => '모두 읽음';

  @override
  String get notification_empty => '알림이 없습니다';

  @override
  String get notification_deleteError => '삭제 중 오류가 발생했습니다.';

  @override
  String get notification_justNow => '방금 전';

  @override
  String notification_minutesAgo(int minutes) {
    return '$minutes분 전';
  }

  @override
  String notification_hoursAgo(int hours) {
    return '$hours시간 전';
  }

  @override
  String notification_daysAgo(int days) {
    return '$days일 전';
  }

  @override
  String get schedule_saveError => '일정 저장 중 오류가 발생했습니다.';

  @override
  String get schedule_deleted => '일정이 삭제되었습니다.';

  @override
  String get schedule_deleteError => '일정 삭제 중 오류가 발생했습니다.';

  @override
  String schedule_reminderMinutes(int minutes) {
    return '$minutes분 전';
  }

  @override
  String get btn_save => '저장';

  @override
  String get btn_saveRecord => '저장하기';

  @override
  String get error_network => '네트워크 연결을 확인해 주세요.';

  @override
  String get error_server => '서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get error_authRequired => '로그인이 필요합니다.';

  @override
  String get error_conflict => '이미 등록된 정보가 있습니다.';

  @override
  String get error_invalidData => '입력 정보를 다시 확인해 주세요.';

  @override
  String get error_notFound => '요청하신 정보를 찾을 수 없습니다.';

  @override
  String get error_savePetFailed => '펫 정보 저장에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get error_saveWeightFailed => '체중 기록 저장에 실패했습니다. 다시 시도해 주세요.';

  @override
  String get error_loginInvalidCredentials => '이메일 또는 비밀번호가 올바르지 않습니다.';

  @override
  String get error_loginUserNotFound => '등록되지 않은 이메일입니다.';

  @override
  String get error_signupEmailExists => '이미 가입된 이메일입니다. 로그인해 주세요.';

  @override
  String get error_signupInvalidData => '입력 정보를 다시 확인해 주세요. (비밀번호는 8자 이상)';

  @override
  String get error_forgotPasswordUserNotFound => '해당 이메일로 가입된 계정이 없습니다.';

  @override
  String get error_tooManyRequests => '요청이 너무 많습니다. 잠시 후 다시 시도해 주세요.';

  @override
  String get error_socialAccountConflict => '이미 다른 계정에 연동된 소셜 계정입니다.';

  @override
  String get snackbar_savedOffline => '오프라인으로 저장되었습니다. 연결 시 자동 동기화됩니다.';

  @override
  String get coach_wciCard_title => '건강 상태';

  @override
  String get coach_wciCard_body => 'WCI 건강 상태를 확인하세요.\n데이터가 쌓일수록 더 정확해져요!';

  @override
  String get coach_weightCard_title => '체중 기록';

  @override
  String get coach_weightCard_body =>
      '여기서 체중을 기록해보세요!\n매일 기록하면 건강 변화를 추적할 수 있어요.';

  @override
  String get coach_foodCard_title => '사료 기록';

  @override
  String get coach_foodCard_body => '사료 취식량을 기록해보세요.\n정확한 건강 분석에 도움이 돼요.';

  @override
  String get coach_healthSignalCard_title => '오늘의 건강 신호';

  @override
  String get coach_healthSignalCard_body => 'AI가 분석한 건강 신호를 확인해보세요.';

  @override
  String get coach_waterCard_title => '수분 기록';

  @override
  String get coach_waterCard_body => '음수량을 기록해보세요.\n수분 섭취도 건강 관리의 중요한 요소예요.';

  @override
  String get coach_recordsTab_title => '기록 탭';

  @override
  String get coach_recordsTab_body => '여기서 체중 변화와 일정을\n한눈에 확인할 수 있어요.';

  @override
  String get coach_chatbotTab_title => '앵박사';

  @override
  String get coach_chatbotTab_body => '앵무새에 대해 궁금한 점이 있다면\nAI 앵박사에게 물어보세요!';

  @override
  String get coach_aiHealthCheck_title => 'AI 건강체크';

  @override
  String get coach_aiHealthCheck_body =>
      '사진 한 장으로 건강 상태를 AI가 분석해드려요.\n탭해서 바로 시작해보세요!';

  @override
  String get coach_insights_title => '주간 인사이트';

  @override
  String get coach_insights_body =>
      'AI가 분석한 건강 인사이트를 확인하세요.\n기록이 쌓일수록 더 정확해져요.';

  @override
  String get coach_recordToggle_title => '기간 전환';

  @override
  String get coach_recordToggle_body => '주간/월간 버튼을 눌러 기간별 체중 변화를 확인하세요.';

  @override
  String get coach_recordChart_title => '체중 차트';

  @override
  String get coach_recordChart_body => '차트에서 체중 추이를 한눈에 확인할 수 있어요.';

  @override
  String get coach_recordCalendar_title => '캘린더';

  @override
  String get coach_recordCalendar_body => '날짜를 선택하면 해당 날의 기록을 볼 수 있어요.';

  @override
  String get coach_recordAddBtn_title => '기록 추가';

  @override
  String get coach_recordAddBtn_body => '이 버튼을 눌러 새 체중을 기록하세요.';

  @override
  String get coach_recordSchedule_title => '일정 관리';

  @override
  String get coach_recordSchedule_body =>
      '선택한 날짜의 일정을 확인하고 관리하세요.\n병원 방문, 투약 일정 등을 기록할 수 있어요.';

  @override
  String get coach_recordDailyRecord_title => '일일 기록';

  @override
  String get coach_recordDailyRecord_body =>
      '매일의 상태와 특이사항을 기록하세요.\n건강 패턴 파악에 도움이 돼요.';

  @override
  String get coach_chatSuggestion_title => '추천 질문';

  @override
  String get coach_chatSuggestion_body => '궁금한 주제를 탭하면 바로 AI에게 물어볼 수 있어요.';

  @override
  String get coach_chatInput_title => '질문 입력';

  @override
  String get coach_chatInput_body => '직접 질문을 입력해서 앵박사에게 물어보세요.';

  @override
  String get coach_next => '다음';

  @override
  String get coach_gotIt => '알겠어요!';

  @override
  String get coach_skip => '건너뛰기';

  @override
  String get coach_foodToggle_title => '식단 유형';

  @override
  String get coach_foodToggle_body => '배식과 취식을 전환해서 제공량과 섭취량을 모두 기록하세요.';

  @override
  String get coach_foodAdd_title => '사료 추가';

  @override
  String get coach_foodAdd_body => '여기를 탭해서 사료 이름, 양, 시간을 기록하세요.';

  @override
  String get coach_foodSave_title => '변경사항 저장';

  @override
  String get coach_foodSave_body => '저장을 잊지 마세요! 온라인 시 자동으로 동기화됩니다.';

  @override
  String get coach_waterIcon_title => '음수량 기록';

  @override
  String get coach_waterIcon_body =>
      '물 아이콘을 탭해서 섭취량을 늘리세요. 길게 눌러 직접 입력할 수도 있어요.';

  @override
  String get coach_waterTarget_title => '일일 목표';

  @override
  String get coach_waterTarget_body => '권장 일일 음수량이 표시됩니다. 충분한 수분 섭취가 중요해요!';

  @override
  String get coach_weightGauge_title => '체중 컨디션 지수';

  @override
  String get coach_weightGauge_body => '품종별 건강 체중 범위를 확인할 수 있어요.';

  @override
  String get coach_weightInput_title => '체중 입력';

  @override
  String get coach_weightInput_body =>
      '그램 단위로 입력하세요. 아침에 측정하면 일관성 있게 기록할 수 있어요!';

  @override
  String get coach_weightTime_title => '측정 시간';

  @override
  String get coach_weightTime_body => '체중을 측정한 시간을 선택하세요. 하루에 여러 번 기록할 수 있어요.';

  @override
  String get coach_weightSave_title => '기록 저장';

  @override
  String get coach_weightSave_body =>
      '탭해서 저장하세요. 데이터가 성장 추이와 건강 변화를 감지하는 데 도움이 돼요.';

  @override
  String get coach_hcHistory_title => '기록 보기';

  @override
  String get coach_hcHistory_body =>
      '과거 건강 체크 기록을 확인하세요. 시간에 따른 패턴을 추적할 수 있어요.';

  @override
  String get coach_hcModes_title => '체크 유형 선택';

  @override
  String get coach_hcModes_body =>
      '전체 건강은 Full Body, 특정 부위는 Part-Specific, 배설물/사료는 해당 모드를 선택하세요.';

  @override
  String get coach_hcTrial_title => '무료 체험 가능';

  @override
  String get coach_hcTrial_body =>
      '무료 건강 체크 횟수가 남아있어요! 프리미엄은 무제한으로 사용할 수 있습니다.';

  @override
  String get coach_hcHistoryVet_title => '수의사 리포트';

  @override
  String get coach_hcHistoryVet_body => '수의사용 종합 리포트를 받아보세요. 프리미엄 기능입니다.';

  @override
  String get coach_hcHistoryShare_title => '리포트 공유';

  @override
  String get coach_hcHistoryShare_body => '이메일이나 메시징 앱으로 건강 리포트를 공유하세요.';

  @override
  String get coach_hcHistorySwipe_title => '스와이프 삭제';

  @override
  String get coach_hcHistorySwipe_body =>
      '기록 카드를 왼쪽으로 밀어 삭제하세요. 삭제는 되돌릴 수 없으니 주의하세요!';

  @override
  String get coach_hcResultConfidence_title => '신뢰도 점수';

  @override
  String get coach_hcResultConfidence_body =>
      'AI 분석의 신뢰도를 나타냅니다. 높을수록 좋지만, 우려 사항은 항상 수의사와 상담하세요.';

  @override
  String get coach_hcResultFindings_title => '분석 결과';

  @override
  String get coach_hcResultFindings_body =>
      'AI 건강 체크의 세부 관찰 내용입니다. 카드를 탭해 자세히 보세요.';

  @override
  String get coach_hcResultRecheck_title => '재검사 가능';

  @override
  String get coach_hcResultRecheck_body =>
      '만족스럽지 않으세요? 다른 사진을 찍어 즉시 재검사할 수 있어요.';

  @override
  String get coach_bhiRing_title => '건강 지수';

  @override
  String get coach_bhiRing_body => '체중, 사료, 수분 데이터로 계산된 100점 만점 건강 점수입니다.';

  @override
  String get coach_bhiBreakdown_title => '점수 구성';

  @override
  String get coach_bhiBreakdown_body =>
      '체중(60점), 사료(25점), 수분(15점)이 총점에 어떻게 기여하는지 확인하세요.';

  @override
  String get coach_profilePremium_title => '프리미엄 업그레이드';

  @override
  String get coach_profilePremium_body =>
      '무제한 AI 건강 체크, 리포트 내보내기, 고급 인사이트를 잠금 해제하세요!';

  @override
  String get coach_profileAddPet_title => '반려동물 추가';

  @override
  String get coach_profileAddPet_body =>
      '여러 마리를 키우시나요? 여기서 추가하고 프로필을 쉽게 전환하세요.';

  @override
  String get coach_profilePetCard_title => '활성 반려동물 선택';

  @override
  String get coach_profilePetCard_body =>
      '펫 카드를 탭해 전환하세요. 활성 펫의 데이터가 앱 전체에 표시됩니다.';

  @override
  String get coach_premiumPlan_title => '플랜 선택';

  @override
  String get coach_premiumPlan_body =>
      '월간은 유연성을, 연간은 2개월 무료 혜택을 드려요. 둘 다 모든 기능을 잠금 해제합니다!';

  @override
  String get coach_premiumPromo_title => '프로모 코드가 있으신가요?';

  @override
  String get coach_premiumPromo_body =>
      '파트너사나 이벤트 코드가 있으세요? 여기를 탭해 특별 혜택을 받으세요.';

  @override
  String get coach_petDetailImage_title => '펫 사진 추가';

  @override
  String get coach_petDetailImage_body =>
      '탭해서 반려조의 사진을 업로드하세요. 한눈에 식별하는 데 도움이 돼요!';

  @override
  String get coach_petDetailInfo_title => '기본 정보';

  @override
  String get coach_petDetailInfo_body =>
      '성별, 생년월일, 품종을 입력하면 더 정확한 건강 권장사항을 받을 수 있어요.';

  @override
  String get coach_petDetailSave_title => '프로필 저장';

  @override
  String get coach_petDetailSave_body => '변경사항을 저장하세요! 모든 기기에서 동기화됩니다.';

  @override
  String get weight_selectTime => '측정 시간';

  @override
  String get weight_timeNotRecorded => '시간 미기록';

  @override
  String get weight_dailyAverage => '일평균';

  @override
  String weight_multipleRecords(int count) {
    return '$count회 측정';
  }

  @override
  String get weight_addAnother => '추가 기록';

  @override
  String get weight_deleteRecord => '이 기록을 삭제하시겠습니까?';

  @override
  String get weight_deleteConfirm => '삭제';

  @override
  String get weight_amPeriod => '오전';

  @override
  String get weight_pmPeriod => '오후';

  @override
  String get diet_serving => '배식';

  @override
  String get diet_eating => '취식';

  @override
  String get diet_addServing => '배식 기록 추가';

  @override
  String get diet_addEating => '취식 기록 추가';

  @override
  String get diet_addRecord => '기록 추가';

  @override
  String get diet_editRecord => '기록 수정';

  @override
  String get diet_recentFoods => '최근 음식';

  @override
  String get diet_totalServed => '총 배식량';

  @override
  String get diet_totalEaten => '총 취식량';

  @override
  String get diet_eatingRate => '취식률';

  @override
  String diet_eatingRateValue(int rate) {
    return '$rate%';
  }

  @override
  String get diet_selectTime => '급여/섭취 시간';

  @override
  String diet_servingSummary(int count, String grams) {
    return '배식 $count회 · ${grams}g';
  }

  @override
  String diet_eatingSummary(int count, String grams) {
    return '취식 $count회 · ${grams}g';
  }

  @override
  String get diet_selectType => '기록 유형';

  @override
  String get diet_foodName => '음식 이름';

  @override
  String get diet_amount => '양(g)';

  @override
  String get diet_memo => '메모 (선택)';

  @override
  String get diet_noServingExists =>
      '배식 기록이 없습니다. 취식 기록을 추가하려면 먼저 배식을 등록해 주세요.';

  @override
  String diet_eatingExceedsServing(String remaining) {
    return '취식량이 배식량을 초과할 수 없습니다. (남은 배식량: ${remaining}g)';
  }

  @override
  String get faq_title => '자주 묻는 질문';

  @override
  String get faq_categoryGeneral => '일반';

  @override
  String get faq_categoryUsage => '기능 사용법';

  @override
  String get faq_categoryAccount => '계정 관리';

  @override
  String get faq_categoryPet => '반려동물 관리';

  @override
  String get faq_q1 => '이 앱은 무료인가요?';

  @override
  String get faq_a1 =>
      'Perch Care의 기본 기능은 무료입니다. 프리미엄 서비스 가입 시 AI 비전 건강체크 등 추가 기능을 이용할 수 있습니다.';

  @override
  String get faq_q2 => 'AI 건강 분석은 얼마나 정확한가요?';

  @override
  String get faq_a2 =>
      'AI 분석은 참고용이며, 정확한 진단을 대체하지 않습니다. 반려동물의 건강에 이상이 있다면 반드시 수의사와 상담해 주세요.';

  @override
  String get faq_q3 => '데이터는 안전하게 보존되나요?';

  @override
  String get faq_a3 =>
      '모든 데이터는 암호화되어 안전하게 서버에 저장됩니다. 기기를 변경하더라도 로그인하면 데이터가 복원됩니다.';

  @override
  String get faq_q4 => '체중은 어떻게 기록하나요?';

  @override
  String get faq_a4 => '하단 네비게이션의 체중 탭에서 날짜를 선택하고 체중(g)을 입력하면 됩니다.';

  @override
  String get faq_q5 => '사료/수분 기록은 어떻게 하나요?';

  @override
  String get faq_a5 =>
      '홈 화면의 사료 또는 수분 카드를 탭하면 기록 화면으로 이동합니다. 각 항목을 추가하고 저장하세요.';

  @override
  String get faq_q6 => 'BHI(건강지수)는 무엇인가요?';

  @override
  String get faq_a6 =>
      'BHI(Bird Health Index)는 체중, 사료, 수분 기록을 종합하여 반려조의 건강 상태를 점수로 보여주는 지표입니다.';

  @override
  String get faq_q7 => '기록을 수정하거나 삭제할 수 있나요?';

  @override
  String get faq_a7 => '네, 사료 기록은 항목을 탭하면 수정할 수 있습니다. 삭제는 항목을 왼쪽으로 스와이프하면 됩니다.';

  @override
  String get faq_q8 => '언어를 변경하려면 어떻게 하나요?';

  @override
  String get faq_a8 => '프로필 화면의 \'언어 설정\'에서 한국어, English, 中文 중 선택할 수 있습니다.';

  @override
  String get faq_q9 => '소셜 계정을 연동하거나 해제하려면?';

  @override
  String get faq_a9 =>
      '프로필 화면의 \'소셜 계정 연동\'에서 Google, Apple 계정을 연동하거나 해제할 수 있습니다.';

  @override
  String get faq_q10 => '회원 탈퇴하면 데이터는 어떻게 되나요?';

  @override
  String get faq_a10 => '탈퇴 시 모든 개인정보와 반려동물 기록이 영구적으로 삭제되며 복구할 수 없습니다.';

  @override
  String get faq_q11 => '반려동물을 추가하거나 삭제하려면?';

  @override
  String get faq_a11 =>
      '프로필 화면의 \'나의 반려가족\'에서 (+) 버튼으로 추가하고, (X) 버튼으로 삭제할 수 있습니다.';

  @override
  String get faq_q12 => '어떤 종을 지원하나요?';

  @override
  String get faq_a12 =>
      '현재 앵무새류(사랑앵무, 왕관앵무 등)를 지원하고 있으며, 다른 조류 종은 추후 지원 예정입니다.';

  @override
  String get faq_q13 => 'Android나 HarmonyOS도 지원하나요?';

  @override
  String get faq_a13 =>
      '현재는 iOS만 지원하고 있습니다. Android 및 HarmonyOS 버전은 개발 중이며, 추후 출시 예정입니다.';

  @override
  String get faq_categoryPremium => '프리미엄';

  @override
  String get faq_q14 => '프리미엄 서비스는 무엇인가요?';

  @override
  String get faq_a14 =>
      '프리미엄 서비스는 AI 비전 건강체크 무제한 이용, 이미지 기반 정밀 분석 등의 고급 기능을 제공합니다.';

  @override
  String get faq_q15 => '프리미엄 코드는 어떻게 사용하나요?';

  @override
  String get faq_a15 =>
      '프로필 화면의 \'프리미엄\' 메뉴에서 PERCH-XXXX-XXXX 형식의 코드를 입력하면 즉시 활성화됩니다.';

  @override
  String get faq_q16 => '프리미엄 만료 시 데이터는 어떻게 되나요?';

  @override
  String get faq_a16 =>
      '프리미엄 만료 후에도 기존 건강체크 텍스트 결과는 유지됩니다. 단, 건강체크 이미지는 만료 후 90일 경과 시 서버에서 자동 삭제됩니다.';

  @override
  String get faq_q17 => 'AI 비전 건강체크는 어떻게 사용하나요?';

  @override
  String get faq_a17 =>
      '홈 화면의 \'AI 건강체크\' 버튼을 탭한 후, 분석 유형(전체 외형/부위별/배변/먹이)을 선택하고 사진을 촬영하거나 앨범에서 선택하세요.';

  @override
  String get faq_q18 => '어떤 부위를 분석할 수 있나요?';

  @override
  String get faq_a18 =>
      '전체 외형, 눈, 부리, 깃털, 발을 개별적으로 분석할 수 있으며, 배변 상태 및 먹이 안전성도 확인할 수 있습니다.';

  @override
  String get faq_q19 => '건강체크 기록은 어디서 볼 수 있나요?';

  @override
  String get faq_a19 => 'AI 건강체크 화면 상단의 \'기록\' 버튼을 탭하면 건강체크 결과를 확인할 수 있습니다.';

  @override
  String get faq_q20 => 'AI 백과사전(챗봇)은 어떻게 사용하나요?';

  @override
  String get faq_a20 =>
      '홈 화면에서 AI 백과사전 배너를 탭하면 반려조 관련 질문을 할 수 있는 채팅 화면으로 이동합니다.';

  @override
  String get faq_q21 => '채팅 기록은 저장되나요?';

  @override
  String get faq_a21 =>
      '네, 채팅 기록은 서버에 안전하게 저장됩니다. 로그아웃 후 다시 로그인해도 이전 대화를 확인할 수 있습니다.';

  @override
  String get faq_q22 => '품종별 표준 체중 정보는 어디서 확인하나요?';

  @override
  String get faq_a22 =>
      '체중 기록 화면에서 품종별 표준 체중 범위가 차트에 표시됩니다. 반려동물 프로필에서 품종을 설정하세요.';

  @override
  String get premium_sectionTitle => '프리미엄';

  @override
  String get premium_title => '프리미엄 코드 입력';

  @override
  String get premium_badgeFree => 'Free';

  @override
  String get premium_badgePremium => 'Premium';

  @override
  String premium_expiresAt(String date) {
    return '$date까지';
  }

  @override
  String get premium_enterCode => '프리미엄 코드를 입력해 보세요';

  @override
  String get premium_benefitsTitle => '프리미엄 혜택';

  @override
  String get premium_benefit1 => 'AI 비전 건강 체크 무제한 이용';

  @override
  String get premium_benefit2 => '이미지 기반 건강 상태 정밀 분석';

  @override
  String get premium_benefit3 => '조기 건강 이상 징후 감지';

  @override
  String get premium_codeInputTitle => '프리미엄 코드';

  @override
  String get premium_codeInputHint => 'PERCH-XXXX-XXXX';

  @override
  String get premium_activateButton => '코드 활성화';

  @override
  String get premium_invalidCodeFormat => '올바른 코드 형식이 아닙니다. (PERCH-XXXX-XXXX)';

  @override
  String get premium_activationFailed => '코드 활성화에 실패했습니다. 코드를 다시 확인해주세요.';

  @override
  String get premium_activationError => '코드 활성화 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';

  @override
  String get premium_rateLimitExceeded => '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.';

  @override
  String get premium_activationSuccessTitle => '프리미엄 활성화 완료!';

  @override
  String premium_activationSuccessContent(String date) {
    return '$date까지 프리미엄 서비스를 이용할 수 있습니다.';
  }

  @override
  String get premium_activationSuccessContentNoDate => '프리미엄 서비스가 활성화되었습니다.';

  @override
  String get premium_upgradeToPremium => '프리미엄 업그레이드';

  @override
  String get premium_healthCheckBlocked =>
      '프리미엄 전용 기능입니다.\n프리미엄 플랜으로 업그레이드해주세요.';

  @override
  String get premium_healthCheckBlockedTitle => '프리미엄 전용 기능';

  @override
  String get hc_title => 'AI 건강체크';

  @override
  String get hc_photoSubtitle => '사진 한 장으로 건강 상태를 확인하세요';

  @override
  String get hc_selectTarget => '분석 대상을 선택해주세요';

  @override
  String get hc_analyze => '분석하기';

  @override
  String get hc_modeFullBody => '전체 외형';

  @override
  String get hc_modeFullBodyDesc => '전체 모습을 촬영하여 외형을 분석합니다';

  @override
  String get hc_modePartSpecific => '부위별 검사';

  @override
  String get hc_modePartSpecificDesc => '눈, 부리, 깃털, 발 등 특정 부위를 분석합니다';

  @override
  String get hc_modeDroppings => '배변 분석';

  @override
  String get hc_modeDroppingsDesc => '배변 사진으로 건강 상태를 확인합니다';

  @override
  String get hc_modeFood => '먹이 안전성';

  @override
  String get hc_modeFoodDesc => '먹이 사진으로 급여 가능 여부를 확인합니다';

  @override
  String get hc_partEye => '눈';

  @override
  String get hc_partBeak => '부리';

  @override
  String get hc_partFeather => '깃털';

  @override
  String get hc_partFoot => '발';

  @override
  String get hc_imageSizeExceeded => '이미지 크기가 10MB를 초과합니다';

  @override
  String hc_imagePickError(String error) {
    return '이미지 선택 중 오류가 발생했습니다: $error';
  }

  @override
  String get hc_takePhoto => '촬영하기';

  @override
  String get hc_selectFromAlbum => '앨범에서 선택';

  @override
  String get hc_photoHint => '사진을 촬영하거나\n앨범에서 선택해주세요';

  @override
  String get hc_registerPetFirst => '펫을 먼저 등록해주세요';

  @override
  String get hc_analysisError => '분석 중 오류가 발생했습니다.\n다시 시도해주세요.';

  @override
  String get hc_cancelAnalysis => '분석 취소';

  @override
  String get hc_cancelAnalysisConfirm => '분석을 취소하시겠습니까?';

  @override
  String get hc_continueAnalysis => '계속 분석';

  @override
  String get hc_analyzing => '분석 중입니다...';

  @override
  String get hc_aiAnalyzing => 'AI가 이미지를 분석하고 있어요';

  @override
  String get hc_analysisErrorTitle => '분석 중 오류가 발생했습니다';

  @override
  String get hc_retry => '다시 시도';

  @override
  String get hc_goBack => '돌아가기';

  @override
  String get hc_resultTitle => '분석 결과';

  @override
  String get hc_analysisItems => '분석 항목';

  @override
  String get hc_recommendations => '권장 사항';

  @override
  String get hc_overallStatus => '종합 상태';

  @override
  String get hc_confidence => '신뢰도';

  @override
  String get hc_vetVisitRecommended => '수의사 방문을 권장합니다';

  @override
  String get hc_possibleCauses => '가능한 원인';

  @override
  String get hc_possibleCausesPrefix => '가능 원인: ';

  @override
  String get hc_nutritionBalance => '영양 균형';

  @override
  String get hc_goHome => '홈으로';

  @override
  String get hc_recheckButton => '다시 체크하기';

  @override
  String hc_colorTexture(String color, String texture) {
    return '색상: $color, 질감: $texture';
  }

  @override
  String get hc_severityNormal => '정상';

  @override
  String get hc_severityCaution => '주의';

  @override
  String get hc_severityWarning => '경고';

  @override
  String get hc_severityCritical => '위험';

  @override
  String get hc_severityUnknown => '확인 필요';

  @override
  String get hc_areaFeather => '깃털 상태';

  @override
  String get hc_areaPosture => '자세/균형';

  @override
  String get hc_areaEye => '눈 상태';

  @override
  String get hc_areaBeak => '부리 상태';

  @override
  String get hc_areaFoot => '발/발톱';

  @override
  String get hc_areaBodyShape => '체형';

  @override
  String get hc_areaFeces => '변';

  @override
  String get hc_areaUrates => '요산';

  @override
  String get hc_areaUrine => '소변';

  @override
  String get hc_areaInjuryDetected => '부상 감지';

  @override
  String get hc_aspectPlantarSurface => '발바닥 상태';

  @override
  String get hc_aspectNailLength => '발톱 길이';

  @override
  String get hc_aspectSwelling => '부종';

  @override
  String get hc_aspectSkinTexture => '피부 질감';

  @override
  String get hc_aspectGripStrength => '쥐는 힘';

  @override
  String get hc_aspectToeAlignment => '발가락 정렬';

  @override
  String get hc_aspectBurns => '화상';

  @override
  String get hc_aspectLacerations => '열상';

  @override
  String get hc_aspectFractures => '골절';

  @override
  String get hc_aspectBiteWounds => '교상';

  @override
  String get hc_aspectBandInjuries => '밴드 손상';

  @override
  String get hc_aspectDischarge => '분비물';

  @override
  String get hc_aspectPupilResponse => '동공 반응';

  @override
  String get hc_aspectCornealClarity => '각막 투명도';

  @override
  String get hc_aspectPeriorbitalArea => '눈 주변부';

  @override
  String get hc_aspectSymmetry => '대칭성';

  @override
  String get hc_aspectCornealScratches => '각막 손상';

  @override
  String get hc_aspectForeignBody => '이물질';

  @override
  String get hc_aspectColor => '색상';

  @override
  String get hc_aspectTexture => '질감';

  @override
  String get hc_aspectOvergrowth => '과성장';

  @override
  String get hc_aspectCracks => '갈라짐';

  @override
  String get hc_aspectPeeling => '벗겨짐';

  @override
  String get hc_aspectCereCondition => '코비늘 상태';

  @override
  String get hc_aspectAlignment => '정렬 상태';

  @override
  String get hc_aspectDensity => '밀도';

  @override
  String get hc_aspectLuster => '윤기';

  @override
  String get hc_aspectDiscoloration => '변색';

  @override
  String get hc_aspectDamagePatterns => '손상 패턴';

  @override
  String get hc_aspectPluckingSigns => '깃털 뽑기 흔적';

  @override
  String get hc_aspectPinFeathers => '솜깃털';

  @override
  String get hc_aspectStressBars => '스트레스 바';

  @override
  String get hc_aspectMoltingStatus => '환우 상태';

  @override
  String get hc_firstAidTitle => '응급 처치';

  @override
  String get hc_notesHint => '부상이나 사고 상황을 설명해 주세요 (선택사항)';

  @override
  String get hc_notesHintFullBody => '전반적인 건강 상태나 특이사항을 설명해 주세요 (선택사항)';

  @override
  String get hc_notesHintDroppings => '배변의 색상, 형태, 빈도 등 특이사항을 설명해 주세요 (선택사항)';

  @override
  String get hc_notesHintFood => '먹이 종류, 섭취량, 식욕 변화 등을 설명해 주세요 (선택사항)';

  @override
  String get ai_petInfoPrefix => '이름';

  @override
  String get ai_breedPrefix => '품종';

  @override
  String get ai_agePrefix => '나이';

  @override
  String get ai_birthdayPrefix => '생일';

  @override
  String get ai_genderMale => '수컷';

  @override
  String get ai_genderFemale => '암컷';

  @override
  String get ai_genderUnknown => '성별 미상';

  @override
  String get ai_petContextInstruction => '사용자가 다중 프로필에서 선택한 앵무새 정보를 참고해.';

  @override
  String get ai_petContextAdvice => '가능한 한 위 앵무새 조건(특히 품종)을 기준으로 맞춤 조언을 제공해.';

  @override
  String ai_ageYears(int years) {
    return '$years세';
  }

  @override
  String ai_ageMonths(int months) {
    return '$months개월';
  }

  @override
  String get ai_ageLessThanMonth => '1개월 미만';

  @override
  String get hc_history => '기록';

  @override
  String get hc_historyTitle => '건강체크 기록';

  @override
  String get hc_historyEmpty => '아직 건강체크 기록이 없어요';

  @override
  String get hc_historyEmptyDesc => 'AI 건강체크를 통해 앵무새의 건강을 확인해보세요';

  @override
  String get hc_savedSuccessfully => '결과가 저장되었습니다';

  @override
  String get hc_deleteConfirm => '이 기록을 삭제하시겠습니까?';

  @override
  String get hc_deleteSuccess => '기록이 삭제되었습니다';

  @override
  String get hc_dateToday => '오늘';

  @override
  String get hc_dateYesterday => '어제';

  @override
  String get hc_dateLast7Days => '최근 7일';

  @override
  String get hc_dateEarlier => '이전';

  @override
  String get premium_featureLockedTitle => '프리미엄 전용 기능';

  @override
  String get premium_featureLockedMessage =>
      'AI 비전 건강체크는 프리미엄 전용 기능입니다.\n\n비전 AI 모델 비용이 높아 무료로 제공하기 어려운 점 양해 부탁드립니다.\n프리미엄 코드를 활성화하면 무제한으로 이용하실 수 있습니다.';

  @override
  String get premium_activateNow => '프리미엄 활성화';

  @override
  String get premium_maybeLater => '나중에';

  @override
  String get chatbot_premiumBanner => '프리미엄 버전으로 더 상세하고 정확한 답변을 받을 수 있어요';

  @override
  String get chatbot_premiumUpgrade => '업그레이드';

  @override
  String get paywall_title => 'Premium';

  @override
  String get paywall_headline => '사진과 기록으로 더 정확하게\n건강 상태를 파악하세요';

  @override
  String get paywall_benefit1 => '무제한 AI Vision 건강체크';

  @override
  String get paywall_benefit2 => '기록 기반 맞춤형 AI 해석';

  @override
  String get paywall_benefit3 => '이상 징후 조기 발견 분석';

  @override
  String get paywall_planMonthly => '월간';

  @override
  String get paywall_planYearly => '연간';

  @override
  String get paywall_yearlyDiscount => '연간 플랜 추천';

  @override
  String paywall_yearlyPerMonth(String price) {
    return '월 $price';
  }

  @override
  String get paywall_ctaButton => 'Premium 시작하기';

  @override
  String get paywall_restore => '구매 복원';

  @override
  String get paywall_promoCode => '프로모션 코드 입력';

  @override
  String get paywall_purchaseSuccessTitle => 'Premium 활성화 완료!';

  @override
  String get paywall_purchaseSuccessContent => '이제 모든 프리미엄 기능을 이용할 수 있습니다.';

  @override
  String get paywall_purchaseFailed => '구매 처리 중 오류가 발생했습니다. 다시 시도해주세요.';

  @override
  String get paywall_restoreSuccess => '구매가 복원되었습니다.';

  @override
  String get paywall_restoreNoSubscription => '복원할 구독이 없습니다.';

  @override
  String get paywall_restoreFailed => '구매 복원에 실패했습니다.';

  @override
  String get paywall_loading => '처리 중...';

  @override
  String get paywall_storeUnavailable => '스토어를 사용할 수 없습니다.';

  @override
  String get paywall_productsNotFound => '상품 정보를 불러올 수 없습니다.';

  @override
  String get paywall_alreadyPremium => '이미 Premium 사용자입니다.';

  @override
  String paywall_alreadyPremiumExpires(String date) {
    return '$date까지 이용 가능';
  }

  @override
  String quotaBadge_normal(int count) {
    return '오늘 $count회 남음';
  }

  @override
  String get quotaBadge_exhausted => '일일 한도 도달';

  @override
  String get quotaBadge_upgrade => '업그레이드';

  @override
  String get aiEncyclopedia_quotaExhausted =>
      '오늘의 무료 사용 횟수를 모두 사용했어요. 프리미엄으로 업그레이드하면 무제한으로 이용할 수 있어요.';

  @override
  String get aiEncyclopedia_quotaExhaustedHint => '일일 한도 도달 · 프리미엄으로 업그레이드하세요';

  @override
  String get healthCheck_freeTrialBadge => '무료 체험';

  @override
  String get healthCheck_trialExhaustedTitle => '무료 체험 완료';

  @override
  String get healthCheck_trialExhaustedMessage =>
      '무료 체험을 이미 사용하셨어요.\n\n프리미엄을 구독하시면 AI 비전 건강체크를 무제한으로 이용할 수 있습니다.';

  @override
  String get healthCheck_trialExhaustedMessage_v2 =>
      '현재 무료 체험 중이며, 체험 횟수를 모두 사용하셨어요.\n\n프로모션 코드를 입력하거나 SNS로 연락하시면 추가 이용이 가능합니다.';

  @override
  String get healthCheck_trialExhaustedAction_promo => '프로모션 코드 입력';

  @override
  String visionQuotaBadge_normal(int count) {
    return '$count회 남음';
  }

  @override
  String get visionQuotaBadge_exhausted => '체험 소진';

  @override
  String get visionQuotaBadge_upgrade => '코드 입력';

  @override
  String get paywall_freeTrialBanner => '현재 AI 비전 체크와 AI 챗봇은\n무료 체험 중입니다';

  @override
  String get paywall_freeTrialSubtext => '프로모션 코드를 입력하면 더 많은 혜택을 받을 수 있습니다';

  @override
  String get paywall_snsEventTitle => 'SNS 이벤트';

  @override
  String get paywall_snsEventDescription => '팔로우 / 친구추가 후 DM으로 프로모션 코드를 받으세요!';

  @override
  String sns_copied(String label) {
    return '$label 복사됨';
  }

  @override
  String get report_shareFailed => '공유 링크 생성에 실패했습니다.';

  @override
  String get report_shareHealth => '건강 리포트 공유';

  @override
  String get report_vetSummary => '병원 방문 요약';

  @override
  String get report_vetSummaryTitle => '병원 방문 요약';

  @override
  String get report_vetSummaryDesc =>
      '최근 30일간의 건강 데이터를 요약하여\n수의사에게 공유할 수 있는 링크를 생성합니다.';

  @override
  String get report_vetFeatureWeight => '체중 변화 추이';

  @override
  String get report_vetFeatureChecks => 'AI 건강 체크 결과 요약';

  @override
  String get report_vetFeatureNotes => '행동 메모 및 일상 기록';

  @override
  String get report_vetShareButton => '요약 링크 공유하기';

  @override
  String get home_healthSummaryTitle => '건강 변화 요약';

  @override
  String get home_healthSummaryWeightChange => '체중 변화';

  @override
  String get home_healthSummaryAbnormal => '이상 소견 (30일)';

  @override
  String get home_healthSummaryFoodConsistency => '급여 일관성';

  @override
  String get home_healthSummaryWaterConsistency => '음수 일관성';

  @override
  String get home_healthSummaryUpgrade => 'Premium 업그레이드';

  @override
  String get home_insightsTitle => '이번 주 인사이트';

  @override
  String get home_insightsEmpty => '아직 인사이트가 없습니다';

  @override
  String get home_insightsRecommendations => '추천 사항';

  @override
  String get home_insightsUpgrade => 'Premium으로 업그레이드하면\n주간 인사이트를 받을 수 있어요';

  @override
  String get dailyRecord_title => '일일 기록';

  @override
  String get dailyRecord_mood => '기분';

  @override
  String get dailyRecord_activity => '활동량';

  @override
  String get dailyRecord_notes => '메모';

  @override
  String get dailyRecord_notesHint => '오늘 반려조의 특이사항을 기록하세요';

  @override
  String get dailyRecord_moodGreat => '최고';

  @override
  String get dailyRecord_moodGood => '좋음';

  @override
  String get dailyRecord_moodNormal => '보통';

  @override
  String get dailyRecord_moodBad => '나쁨';

  @override
  String get dailyRecord_moodSick => '아픔';

  @override
  String get dailyRecord_saved => '일일 기록이 저장되었습니다';

  @override
  String get dailyRecord_deleted => '일일 기록이 삭제되었습니다';

  @override
  String get dailyRecord_saveError => '일일 기록 저장 중 오류가 발생했습니다';

  @override
  String get dailyRecord_deleteError => '일일 기록 삭제 중 오류가 발생했습니다';

  @override
  String get weightDetail_monthDailyRecord => '이번 달 일일 기록';

  @override
  String weightDetail_dateDailyRecord(int month, int day) {
    return '$month월 $day일 일일 기록';
  }

  @override
  String get weightDetail_noDailyRecord => '등록된 일일 기록이 없습니다';

  @override
  String get weightDetail_noDailyRecordOnDate => '이 날에 등록된 일일 기록이 없습니다';

  @override
  String get weightDetail_addDailyRecordHint => '아래 버튼을 눌러 기록을 추가해보세요';

  @override
  String get btn_addSchedule => '일정 추가';

  @override
  String get btn_addDailyRecord => '일일 기록 추가';

  @override
  String get profileSetup_title => '프로필 설정';

  @override
  String get profileSetup_phoneHint => '전화번호를 입력해 주세요';

  @override
  String get profileSetup_complete => '입력완료';

  @override
  String get profileSetup_saveError => '프로필 저장 중 오류가 발생했습니다.';

  @override
  String get profileSetup_genderSelectTitle => '성별을 선택하세요';

  @override
  String get profileSetup_genderMale => '남';

  @override
  String get profileSetup_genderFemale => '여';

  @override
  String get profileSetup_doneTitle => '설정 완료';

  @override
  String get profileSetup_doneMessage => '설정이 완료되었습니다!';

  @override
  String get profileSetup_startRecording => '기록 시작!';

  @override
  String get timePicker_title => '시간을 선택해주세요';

  @override
  String get timePicker_confirm => '선택 완료';

  @override
  String get country_selectTitle => '국가를 선택하세요';

  @override
  String get datetime_am => '오전';

  @override
  String get datetime_pm => '오후';

  @override
  String datetime_yearMonth(int year, int month) {
    return '$year년 $month월';
  }

  @override
  String get schedule_noPetInfo => '펫 정보가 없습니다.';

  @override
  String get schedule_noTitle => '제목 없음';

  @override
  String get schedule_endTimeAfterStart => '종료 시간은 시작 시간 이후여야 합니다.';

  @override
  String get schedule_titleHint => '제목';

  @override
  String get common_defaultPetName => '사랑이';
}
