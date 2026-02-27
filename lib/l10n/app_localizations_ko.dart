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
  String get login_kakao => '카카오 로그인';

  @override
  String get login_google => '구글로 로그인';

  @override
  String get login_apple => '애플로 로그인';

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
  String get dialog_kakaoLoginTitle => '카카오 로그인 안내';

  @override
  String get dialog_kakaoLoginContent1 => '카카오 정책으로 인해 바로 로그인할 수 없습니다.';

  @override
  String get dialog_kakaoLoginContent2 =>
      '먼저 이메일로 회원가입 후, 마이페이지에서 카카오 계정을 연동하시면 다음부터 카카오 로그인을 사용할 수 있습니다.';

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
  String get profile_unlink => '해제';

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
      '탈퇴하시면 모든 데이터가 삭제되며 복구할 수 없습니다.\n정말 탈퇴하시겠습니까?';

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
  String get error_kakaoLogin => 'Kakao 로그인 중 오류가 발생했습니다.';

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
  String get error_linkKakao => '카카오 계정 연동에 실패했습니다.';

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
  String get snackbar_kakaoLinked => '카카오 계정이 연동되었습니다.';

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
  String get social_kakao => '카카오';

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
  String get faq_a1 => '네, Perch Care의 기본 기능은 모두 무료로 이용할 수 있습니다.';

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
}
