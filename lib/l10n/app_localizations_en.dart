// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get common_save => 'Save';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_confirm => 'OK';

  @override
  String get common_close => 'Close';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_edit => 'Edit';

  @override
  String get common_later => 'Later';

  @override
  String get common_view => 'View';

  @override
  String get common_noData => 'No data available';

  @override
  String get common_loading => 'Loading...';

  @override
  String get common_saveSuccess => 'Saved successfully.';

  @override
  String common_saveError(String error) {
    return 'Error while saving: $error';
  }

  @override
  String get common_updated => 'Updated successfully.';

  @override
  String get common_registered => 'Registered successfully.';

  @override
  String get pet_loadError => 'Failed to load pet information.';

  @override
  String get onboarding_title => 'Nice to meet you!';

  @override
  String get onboarding_description =>
      'Beyond simple records, understand your parrot\'s\ncondition more deeply with AI analysis.';

  @override
  String get btn_start => 'Get Started';

  @override
  String get login_title => 'Login';

  @override
  String get login_kakao => 'Login with Kakao';

  @override
  String get login_google => 'Login with Google';

  @override
  String get login_apple => 'Login with Apple';

  @override
  String get login_button => 'Login';

  @override
  String get login_notMember => 'Not a member yet?';

  @override
  String get login_signup => 'Sign Up';

  @override
  String get login_saveId => 'Remember ID';

  @override
  String get login_findIdPassword => 'Find ID/Password';

  @override
  String get input_email => 'Email';

  @override
  String get input_email_hint => 'Enter your email';

  @override
  String get input_password => 'Password';

  @override
  String get input_password_hint => 'Enter your password';

  @override
  String get input_name => 'Name';

  @override
  String get input_name_hint => 'Enter your name';

  @override
  String get dialog_kakaoLoginTitle => 'Kakao Login Notice';

  @override
  String get dialog_kakaoLoginContent1 =>
      'Due to Kakao\'s policy, direct login is not available.';

  @override
  String get dialog_kakaoLoginContent2 =>
      'Please sign up with email first, then link your Kakao account in My Page to use Kakao login next time.';

  @override
  String get dialog_goSignup => 'Go to Sign Up';

  @override
  String get signup_title => 'Sign Up';

  @override
  String get signup_button => 'Sign Up';

  @override
  String get signup_alreadyMember => 'Already have an account?';

  @override
  String get signup_completeTitle => 'Sign Up Complete';

  @override
  String get signup_completeMessage =>
      'Registration is complete!\nPlease log in to use the service.';

  @override
  String get terms_agreeAll => 'Agree to All';

  @override
  String get terms_requiredTerms => '[Required] Terms of Service';

  @override
  String get terms_requiredPrivacy => '[Required] Privacy Policy';

  @override
  String get terms_optionalMarketing => '[Optional] Marketing Communications';

  @override
  String get terms_termsOfService => 'Terms of Service';

  @override
  String get terms_privacyPolicy => 'Privacy Policy';

  @override
  String get terms_sectionTitle => 'Terms & Policies';

  @override
  String get forgot_title => 'Find Password';

  @override
  String get forgot_description =>
      'Enter the email you used to sign up.\nWe will send you a password reset code.';

  @override
  String get btn_sendCode => 'Send Code';

  @override
  String get forgot_codeTitle => 'Enter Code';

  @override
  String get forgot_codeDescription =>
      'A recovery code has been sent to you.\nPlease enter the code within 2 minutes.';

  @override
  String forgot_codeSentTo(String destination) {
    return 'Code sent to $destination.';
  }

  @override
  String forgot_timeRemaining(String time) {
    return '$time remaining to enter the code.';
  }

  @override
  String get btn_resendCode => 'Resend Code';

  @override
  String get forgot_newPasswordTitle => 'New Password';

  @override
  String get forgot_newPasswordDescription =>
      'Please enter a new password.\nYou cannot use a previously used password.';

  @override
  String get input_newPassword => 'New Password';

  @override
  String get input_confirmPassword => 'Confirm Password';

  @override
  String get btn_resetComplete => 'Reset Complete';

  @override
  String get home_monthlyUnit => 'Monthly';

  @override
  String get home_weeklyUnit => 'Weekly';

  @override
  String get home_wciHealthStatus => 'WCI* Health Status';

  @override
  String home_updatedAgo(int minutes) {
    return 'Updated $minutes min ago';
  }

  @override
  String home_enterDataPrompt(String petName) {
    return 'Enter data for $petName';
  }

  @override
  String get home_checkStatus => 'to check the status.';

  @override
  String home_level(int level) {
    return 'Level $level';
  }

  @override
  String get home_weight => 'Weight';

  @override
  String get home_weightHint => 'Enter weight';

  @override
  String get home_food => 'Food';

  @override
  String get home_foodHint => 'Enter food intake';

  @override
  String get home_water => 'Water';

  @override
  String get home_waterHint => 'Enter water intake';

  @override
  String get home_todayHealthSignal => 'Today\'s';

  @override
  String get home_healthSignal => 'Health Signal';

  @override
  String home_monthFormat(int month) {
    return '$month';
  }

  @override
  String home_weekFormat(int week) {
    return 'Week $week';
  }

  @override
  String get wci_level1 =>
      'Your pet looks light and thin.\nCheck food intake and condition.';

  @override
  String get wci_level2 =>
      'Ribs aren\'t visible but easily felt.\nA tucked waist is visible from the side.';

  @override
  String get wci_level3 =>
      'Overall body shape is stable.\nMaintain current habits and observe lightly.';

  @override
  String get wci_level4 =>
      'Body looks overall round.\nCheck food and treat amounts.';

  @override
  String get wci_level5 =>
      'Overall heavy impression.\nAdjust diet and activity for health.';

  @override
  String get weight_title => 'Weight';

  @override
  String get weight_wciHealthStatus => 'WCI Health Status';

  @override
  String get weight_inputWeight => 'Enter Weight';

  @override
  String get weight_inputHint => 'e.g., 58.3';

  @override
  String get weight_formula => 'Formula';

  @override
  String get weight_formulaText =>
      'WCI(%) = (Current - Baseline) / Baseline x 100';

  @override
  String get weight_calculation => 'Calculation';

  @override
  String get weight_noData => 'No data available.';

  @override
  String get weight_level0Title => 'Level 0';

  @override
  String get weight_level0Desc => 'Please enter weight';

  @override
  String get weight_level1Title => 'Level 1 | Light';

  @override
  String get weight_level1Desc =>
      'Very light. Check food intake and condition.';

  @override
  String get weight_level2Title => 'Level 2 | Slightly Light';

  @override
  String get weight_level2Desc => 'Slim. Maintain current habits and observe.';

  @override
  String get weight_level3Title => 'Level 3 | Ideal';

  @override
  String get weight_level3Desc => 'Best weight balance range. Keep it up!';

  @override
  String get weight_level4Title => 'Level 4 | Slightly Heavy';

  @override
  String get weight_level4Desc => 'Looks a bit heavy. Check meal balance.';

  @override
  String get weight_level5Title => 'Level 5 | Heavy';

  @override
  String get weight_level5Desc =>
      'Significant weight gain. Diet and activity adjustment needed.';

  @override
  String get weight_unitGram => 'g';

  @override
  String get weightDetail_title => 'Records';

  @override
  String get weightDetail_headerLine1 => 'Keep recording consistently';

  @override
  String weightDetail_headerLine2(String petName) {
    return '$petName\'s weight changes at a glance!';
  }

  @override
  String get weightDetail_subLine1 =>
      'Record now and manage your pet\'s health';

  @override
  String get weightDetail_subLine2 => 'conveniently.';

  @override
  String get weightDetail_toggleWeek => 'W';

  @override
  String get weightDetail_toggleMonth => 'M';

  @override
  String weightDetail_recordSummary(String petName, int days) {
    return '$petName\'s weight recorded for $days days';
  }

  @override
  String weightDetail_yearMonth(int year, int month) {
    return '$month $year';
  }

  @override
  String get weightDetail_noPet => 'No active pet. Please add a pet first.';

  @override
  String get weightDetail_noSchedule => 'No scheduled events';

  @override
  String get weightDetail_addScheduleHint =>
      'Tap the button below to add an event';

  @override
  String get weightDetail_monthSchedule => 'This Month\'s Schedule';

  @override
  String get weightDetail_noWeightRecord => 'No weight records this month';

  @override
  String weightDetail_monthWeightRecord(int month) {
    return '$month Weight Records';
  }

  @override
  String get btn_addRecord => 'Add Record';

  @override
  String get weightDetail_today => 'Today';

  @override
  String get profile_title => 'Profile';

  @override
  String get profile_myPets => 'My Pets';

  @override
  String get profile_addNewPet => 'Add New Pet';

  @override
  String get profile_socialAccounts => 'Linked Accounts';

  @override
  String get profile_link => 'Link';

  @override
  String get profile_unlink => 'Unlink';

  @override
  String get profile_accountManagement => 'Account';

  @override
  String get profile_logout => 'Logout';

  @override
  String get profile_deleteAccount => 'Delete Account';

  @override
  String get profile_noSpecies => 'No species info';

  @override
  String get profile_noAge => 'No age info';

  @override
  String profile_ageFormat(int years, int months, int days) {
    return '${years}y ${months}m ${days}d';
  }

  @override
  String get dialog_unlinkTitle => 'Unlink Social Account';

  @override
  String dialog_unlinkContent(String provider) {
    return 'Unlink $provider account?';
  }

  @override
  String get dialog_logoutTitle => 'Logout';

  @override
  String get dialog_logoutContent => 'Are you sure you want to logout?';

  @override
  String get dialog_deleteAccountTitle => 'Delete Account';

  @override
  String get dialog_deleteAccountContent =>
      'All data will be deleted and cannot be recovered.\nAre you sure?';

  @override
  String get dialog_delete => 'Delete';

  @override
  String get pet_profile => 'Profile';

  @override
  String get pet_name_hint => 'Enter name';

  @override
  String get pet_gender_hint => 'Select gender';

  @override
  String get pet_weight_hint => 'Weight';

  @override
  String get pet_birthday_hint => 'Birthday';

  @override
  String get pet_adoptionDate_hint => 'Adoption Date';

  @override
  String get pet_species_hint => 'Species';

  @override
  String get pet_growthStage_hint => 'Select growth stage';

  @override
  String get pet_genderMale => 'Male';

  @override
  String get pet_genderFemale => 'Female';

  @override
  String get pet_genderUnknown => 'Unknown';

  @override
  String get pet_growthRapid => 'Rapid Growth';

  @override
  String get pet_growthPost => 'Post Growth';

  @override
  String get pet_growthAdult => 'Adult';

  @override
  String get dialog_selectGender => 'Select Gender';

  @override
  String get dialog_selectGrowthStage => 'Select Growth Stage';

  @override
  String get error_googleLogin => 'Error during Google login.';

  @override
  String get error_appleLogin => 'Error during Apple login.';

  @override
  String get error_kakaoLogin => 'Error during Kakao login.';

  @override
  String get error_login => 'Error during login.';

  @override
  String get error_loginRetry => 'Login failed. Please try again.';

  @override
  String get error_sendCode => 'Error sending code.';

  @override
  String get error_invalidCode => 'Invalid code. Please try again.';

  @override
  String get error_passwordChange => 'Error changing password.';

  @override
  String get error_unexpected => 'Unexpected error. Please try again.';

  @override
  String error_saveFailed(String error) {
    return 'Error saving: $error';
  }

  @override
  String get error_loadPet => 'Failed to load pet info.';

  @override
  String get error_deleteAccount =>
      'Failed to delete account. Please try again.';

  @override
  String get error_linkGoogle => 'Failed to link Google account.';

  @override
  String get error_linkApple => 'Failed to link Apple account.';

  @override
  String get error_linkKakao => 'Failed to link Kakao account.';

  @override
  String error_unlinkFailed(String provider) {
    return 'Failed to unlink $provider account.';
  }

  @override
  String get snackbar_codeResent => 'Code has been resent.';

  @override
  String get snackbar_passwordChanged => 'Password changed successfully.';

  @override
  String get snackbar_saved => 'Saved.';

  @override
  String get snackbar_updated => 'Updated.';

  @override
  String get snackbar_registered => 'Registered.';

  @override
  String get snackbar_googleLinked => 'Google account linked.';

  @override
  String get snackbar_appleLinked => 'Apple account linked.';

  @override
  String get snackbar_kakaoLinked => 'Kakao account linked.';

  @override
  String snackbar_unlinked(String provider) {
    return '$provider account unlinked.';
  }

  @override
  String get validation_enterEmail => 'Please enter your email.';

  @override
  String get validation_invalidEmail => 'Please enter a valid email.';

  @override
  String get validation_enterPassword => 'Please enter your password.';

  @override
  String get validation_passwordMin8 =>
      'Password must be at least 8 characters';

  @override
  String get validation_enterName => 'Please enter your name';

  @override
  String get validation_checkInput => 'Please check your input';

  @override
  String get validation_enterNewPassword => 'Please enter a new password.';

  @override
  String get validation_confirmPassword => 'Please confirm your password.';

  @override
  String get validation_passwordMismatch => 'Passwords do not match.';

  @override
  String get datetime_weekday_mon => 'Mon';

  @override
  String get datetime_weekday_tue => 'Tue';

  @override
  String get datetime_weekday_wed => 'Wed';

  @override
  String get datetime_weekday_thu => 'Thu';

  @override
  String get datetime_weekday_fri => 'Fri';

  @override
  String get datetime_weekday_sat => 'Sat';

  @override
  String get datetime_weekday_sun => 'Sun';

  @override
  String datetime_dateFormat(int year, int month, int day, String weekday) {
    return '$weekday, $month/$day/$year';
  }

  @override
  String datetime_dateShort(int month, int day, String weekday) {
    return '$month/$day ($weekday)';
  }

  @override
  String get social_kakao => 'Kakao';

  @override
  String get social_google => 'Google';

  @override
  String get social_apple => 'Apple';

  @override
  String get profile_user => 'User';

  @override
  String get profile_userSuffix => '';

  @override
  String get profile_languageSettings => 'Language';

  @override
  String get profile_languageSelect => 'Select Language';

  @override
  String get profile_deviceDefault => 'Device Default';

  @override
  String get profile_deviceDefaultSubtitle => 'Follow system language';

  @override
  String get profile_zeroDay => '0d';

  @override
  String get bhi_title => 'Health Score';

  @override
  String get bhi_noDataTitle => 'No health data yet';

  @override
  String get bhi_noDataSubtitle => 'Please enter weight, food, and water data';

  @override
  String get bhi_scoreComposition => 'Score Breakdown';

  @override
  String get bhi_healthScore => 'BHI Health Score';

  @override
  String get bhi_scoreMax => '/100';

  @override
  String get bhi_noData => 'No data';

  @override
  String get bhi_wciLevel => 'WCI Level';

  @override
  String get bhi_growthStage => 'Growth Stage';

  @override
  String bhi_stageNumber(int stage) {
    return 'Stage $stage';
  }

  @override
  String get bhi_accuracyHint =>
      'The longer you keep records, the more accurate your health score will be.';

  @override
  String bhi_baseDate(String date) {
    return 'Date: $date';
  }

  @override
  String get bhi_statusHealthy => 'Healthy';

  @override
  String get bhi_statusStable => 'Stable';

  @override
  String get bhi_statusCaution => 'Needs Attention';

  @override
  String get bhi_statusManagement => 'Needs Care';

  @override
  String get bhi_statusInsufficient => 'Insufficient Data';

  @override
  String get bhi_descHealthy =>
      'Weight, food, and water are all good.\nKeep up the current habits.';

  @override
  String get bhi_descStable => 'Overall okay, but\ncheck some items.';

  @override
  String get bhi_descCaution =>
      'Changes detected in some items.\nPlease check the data.';

  @override
  String get bhi_descManagement =>
      'Health indicators are on the low side.\nCheck food and water intake.';

  @override
  String get bhi_descInsufficient => 'Enter data to see the health score.';

  @override
  String get bhi_growthAdult => 'Adult';

  @override
  String get bhi_growthPostGrowth => 'Post Growth';

  @override
  String get bhi_growthRapidGrowth => 'Rapid Growth';

  @override
  String get food_title => 'Food';

  @override
  String get food_addTitle => 'Add Food';

  @override
  String get food_editTitle => 'Edit Food';

  @override
  String get food_nameLabel => 'Food Name';

  @override
  String get food_totalIntake => 'Total Intake (g)';

  @override
  String get food_targetAmount => 'Target Amount (g)';

  @override
  String get food_intakeCount => 'Intake Count';

  @override
  String get food_routine => 'Feeding Routine';

  @override
  String get food_addFood => 'Register food being eaten';

  @override
  String get food_dailyTarget => 'Daily Target';

  @override
  String food_recommendedRange(int min, int max) {
    return 'Recommended: $min~${max}g/day';
  }

  @override
  String get food_dailyCount => 'Daily Intake Count';

  @override
  String food_perMeal(int amount) {
    return 'Per meal: ${amount}g';
  }

  @override
  String food_timesCount(int count) {
    return '$count times';
  }

  @override
  String get pet_defaultName => 'Bird';

  @override
  String get wciIndex_title => 'What is WCI?';

  @override
  String get wciIndex_description =>
      'A health index that shows how changes in eating habits\naffect weight as a percentage.';

  @override
  String get wciIndex_calculationMethod => 'Calculation Method';

  @override
  String get wciIndex_levelCriteria => 'WCI 5-Level Criteria';

  @override
  String get chatbot_title => 'Chatbot';

  @override
  String get chatbot_clearHistory => 'Clear Chat History';

  @override
  String get chatbot_clearHistoryConfirm =>
      'All chat history will be deleted. Continue?';

  @override
  String get chatbot_historyCleared => 'Chat history has been cleared.';

  @override
  String get chatbot_welcomeTitle => 'Hello! I\'m Dr. Parrot!';

  @override
  String get chatbot_welcomeDescription =>
      'If you have any questions about parrots,\nfeel free to ask!';

  @override
  String get chatbot_preparingAnswer => 'Preparing an answer...';

  @override
  String get chatbot_aiError => 'AI response failed. Please try again later.';

  @override
  String get chatbot_inputHint => 'Enter your question';

  @override
  String get chatbot_suggestion1 => 'Initial vitamin intake';

  @override
  String get chatbot_suggestion2 => 'Molting care tips';

  @override
  String get chatbot_suggestion3 => 'Health checkup frequency';

  @override
  String get chatbot_suggestion4 => 'Weight recording tips';

  @override
  String chatbot_aiCallFailed(String error) {
    return 'AI call failed: $error';
  }

  @override
  String get water_title => 'Water';

  @override
  String get water_inputTitle => 'Water Intake';

  @override
  String get water_totalIntake => 'Total Intake (ml)';

  @override
  String get water_intakeCount => 'Intake Count';

  @override
  String get water_routine => 'Water Intake Routine';

  @override
  String get water_water => 'Water';

  @override
  String get water_dailyTarget => 'Daily Water Goal';

  @override
  String water_recommendedRange(String amount) {
    return 'Recommended: ${amount}ml/day';
  }

  @override
  String get water_dailyCount => 'Daily Intake Count';

  @override
  String water_perDrink(String amount) {
    return 'Per drink: ${amount}ml';
  }

  @override
  String water_timesCount(int count) {
    return '$count times';
  }

  @override
  String get weight_bodyWeight => 'Body Weight*';

  @override
  String get weight_addStickerHint => 'Tap here to add a sticker.';

  @override
  String get weight_inputLabel => 'Enter Weight (g)';

  @override
  String get weight_recordSuccess => 'Today\'s weight has been recorded!';

  @override
  String get weight_bcs1 =>
      'Bones are easily felt and appears very thin from the side.\nPlease provide more nutrition.';

  @override
  String get weight_bcs2 =>
      'Ribs are easily felt with a thin silhouette.\nWeight is on the low side, consider increasing food.';

  @override
  String get weight_bcs3 =>
      'Ribs aren\'t visible but can be felt with slight touch.\nA tucked waist is visible from the side.';

  @override
  String get weight_bcs4 =>
      'Ribs can be felt but with a slight fat layer.\nSide profile looks rounder, weight has increased slightly.';

  @override
  String get weight_bcs5 =>
      'Ribs are hard to feel and side profile appears round.\nReduce food and increase activity.';

  @override
  String get validation_enterWeight => 'Please enter weight.';

  @override
  String get validation_enterValidNumber => 'Please enter a valid number.';

  @override
  String get validation_weightGreaterThanZero =>
      'Weight must be greater than 0.';

  @override
  String get error_noPetFound => 'No active pet found.';

  @override
  String datetime_lunar(int month, int day) {
    return 'Lunar $month/$day';
  }

  @override
  String get datetime_weekdayFull_sun => 'Sunday';

  @override
  String get datetime_weekdayFull_mon => 'Monday';

  @override
  String get datetime_weekdayFull_tue => 'Tuesday';

  @override
  String get datetime_weekdayFull_wed => 'Wednesday';

  @override
  String get datetime_weekdayFull_thu => 'Thursday';

  @override
  String get datetime_weekdayFull_fri => 'Friday';

  @override
  String get datetime_weekdayFull_sat => 'Saturday';

  @override
  String datetime_minutes(int minutes) {
    return '$minutes min';
  }

  @override
  String datetime_seconds(int seconds) {
    return '$seconds sec';
  }

  @override
  String get notification_title => 'Notifications';

  @override
  String get notification_markAllRead => 'Mark All Read';

  @override
  String get notification_empty => 'No notifications';

  @override
  String get notification_deleteError => 'Error while deleting.';

  @override
  String get notification_justNow => 'Just now';

  @override
  String notification_minutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String notification_hoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String notification_daysAgo(int days) {
    return '${days}d ago';
  }

  @override
  String get schedule_saveError => 'Error saving schedule.';

  @override
  String schedule_reminderMinutes(int minutes) {
    return '$minutes min before';
  }

  @override
  String get btn_save => 'Save';

  @override
  String get btn_saveRecord => 'Save Record';
}
