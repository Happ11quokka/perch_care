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
  String get common_collapse => 'Collapse';

  @override
  String common_showAll(int count) {
    return 'Show all ($count)';
  }

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
  String get password_strength_weak => 'Weak';

  @override
  String get password_strength_medium => 'Medium';

  @override
  String get password_strength_strong => 'Strong';

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
  String home_updatedHoursAgo(int hours) {
    return 'Updated ${hours}h ago';
  }

  @override
  String home_updatedOnDate(int month, int day) {
    return 'Updated on $month/$day';
  }

  @override
  String get home_noUpdateData => 'No data';

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
  String get weight_breedRange => 'Breed Weight Range';

  @override
  String weight_breedRangeIdeal(double min, double max) {
    return 'Ideal: ${min}g - ${max}g';
  }

  @override
  String weight_breedRangeFull(double min, double max) {
    return 'Range: ${min}g - ${max}g';
  }

  @override
  String get breed_selectTitle => 'Select Breed';

  @override
  String get breed_searchHint => 'Search breeds...';

  @override
  String get breed_noBreeds => 'No breeds available';

  @override
  String get breed_notFound => 'No breeds found';

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
  String weightDetail_monthChartLabel(int month) {
    return 'M$month';
  }

  @override
  String schedule_dateDisplay(int month, int day, String weekday) {
    return '$month/$day ($weekday)';
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
  String weightDetail_dateSchedule(int month, int day) {
    return 'Schedule for $month/$day';
  }

  @override
  String get weightDetail_noScheduleOnDate =>
      'No scheduled events for this date';

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
  String get pet_delete => 'Delete Pet';

  @override
  String get pet_deleteConfirmTitle => 'Delete Pet';

  @override
  String get pet_deleteConfirmMessage =>
      'Are you sure you want to delete this pet? All associated data (weight, food, water records) will be permanently deleted.';

  @override
  String get pet_deleteConfirmButton => 'Delete';

  @override
  String get profile_socialAccounts => 'Linked Accounts';

  @override
  String get profile_link => 'Link';

  @override
  String get profile_unlink => 'Unlink';

  @override
  String get profile_appSupport => 'App Support';

  @override
  String get profile_rateApp => 'Rate this app';

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
  String get snackbar_deleted => 'Deleted.';

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
  String get water_tapToInput => 'Tap to enter';

  @override
  String get water_tapToEdit => 'Tap to edit';

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
  String get schedule_deleted => 'Schedule deleted.';

  @override
  String get schedule_deleteError => 'Failed to delete schedule.';

  @override
  String schedule_reminderMinutes(int minutes) {
    return '$minutes min before';
  }

  @override
  String get btn_save => 'Save';

  @override
  String get btn_saveRecord => 'Save Record';

  @override
  String get error_network => 'Please check your network connection.';

  @override
  String get error_server =>
      'A temporary server issue occurred. Please try again later.';

  @override
  String get error_authRequired => 'Login is required.';

  @override
  String get error_conflict => 'This information is already registered.';

  @override
  String get error_invalidData => 'Please check your input again.';

  @override
  String get error_notFound => 'The requested information could not be found.';

  @override
  String get error_savePetFailed =>
      'Failed to save pet info. Please try again.';

  @override
  String get error_saveWeightFailed =>
      'Failed to save weight record. Please try again.';

  @override
  String get coach_wciCard_title => 'Health Status';

  @override
  String get coach_wciCard_body =>
      'Check WCI health status here.\nIt gets more accurate with more data!';

  @override
  String get coach_weightCard_title => 'Weight Record';

  @override
  String get coach_weightCard_body =>
      'Record weight here!\nDaily tracking helps monitor health changes.';

  @override
  String get coach_foodCard_title => 'Food Record';

  @override
  String get coach_foodCard_body =>
      'Record food intake here.\nIt helps with accurate health analysis.';

  @override
  String get coach_healthSignalCard_title => 'Today\'s Health Signal';

  @override
  String get coach_healthSignalCard_body =>
      'Check AI-analyzed health signals here.';

  @override
  String get coach_waterCard_title => 'Water Record';

  @override
  String get coach_waterCard_body =>
      'Record water intake here.\nHydration is key to health management.';

  @override
  String get coach_recordsTab_title => 'Records Tab';

  @override
  String get coach_recordsTab_body =>
      'View weight changes and schedules\nat a glance here.';

  @override
  String get coach_chatbotTab_title => 'Dr. Parrot';

  @override
  String get coach_chatbotTab_body =>
      'Have questions about parrots?\nAsk our AI Dr. Parrot!';

  @override
  String get coach_recordToggle_title => 'Period Toggle';

  @override
  String get coach_recordToggle_body =>
      'Tap Weekly/Monthly to view weight changes by period.';

  @override
  String get coach_recordChart_title => 'Weight Chart';

  @override
  String get coach_recordChart_body =>
      'See your weight trends at a glance in the chart.';

  @override
  String get coach_recordCalendar_title => 'Calendar';

  @override
  String get coach_recordCalendar_body =>
      'Select a date to view records for that day.';

  @override
  String get coach_recordAddBtn_title => 'Add Record';

  @override
  String get coach_recordAddBtn_body =>
      'Tap this button to add a new weight record.';

  @override
  String get coach_chatSuggestion_title => 'Suggestions';

  @override
  String get coach_chatSuggestion_body =>
      'Tap a topic to instantly ask the AI.';

  @override
  String get coach_chatInput_title => 'Ask a Question';

  @override
  String get coach_chatInput_body =>
      'Type your own question to ask the AI doctor.';

  @override
  String get coach_next => 'Next';

  @override
  String get coach_gotIt => 'Got it!';

  @override
  String get coach_skip => 'Skip';

  @override
  String get weight_selectTime => 'Measurement Time';

  @override
  String get weight_timeNotRecorded => 'Time not recorded';

  @override
  String get weight_dailyAverage => 'Daily Avg';

  @override
  String weight_multipleRecords(int count) {
    return '$count measurements';
  }

  @override
  String get weight_addAnother => 'Add Another';

  @override
  String get weight_deleteRecord => 'Delete this record?';

  @override
  String get weight_deleteConfirm => 'Delete';

  @override
  String get weight_amPeriod => 'AM';

  @override
  String get weight_pmPeriod => 'PM';

  @override
  String get diet_serving => 'Served';

  @override
  String get diet_eating => 'Eaten';

  @override
  String get diet_addServing => 'Add Serving Record';

  @override
  String get diet_addEating => 'Add Eating Record';

  @override
  String get diet_addRecord => 'Add Record';

  @override
  String get diet_editRecord => 'Edit Record';

  @override
  String get diet_recentFoods => 'Recent foods';

  @override
  String get diet_totalServed => 'Total Served';

  @override
  String get diet_totalEaten => 'Total Eaten';

  @override
  String get diet_eatingRate => 'Eating Rate';

  @override
  String diet_eatingRateValue(int rate) {
    return '$rate%';
  }

  @override
  String get diet_selectTime => 'Serving/Eating Time';

  @override
  String diet_servingSummary(int count, String grams) {
    return 'Served ${count}x · ${grams}g';
  }

  @override
  String diet_eatingSummary(int count, String grams) {
    return 'Eaten ${count}x · ${grams}g';
  }

  @override
  String get diet_selectType => 'Record Type';

  @override
  String get diet_foodName => 'Food Name';

  @override
  String get diet_amount => 'Amount (g)';

  @override
  String get diet_memo => 'Memo (optional)';

  @override
  String get diet_noServingExists =>
      'No serving records found. Please add a serving record first.';

  @override
  String diet_eatingExceedsServing(String remaining) {
    return 'Eating amount cannot exceed served amount. (Remaining: ${remaining}g)';
  }

  @override
  String get faq_title => 'FAQ';

  @override
  String get faq_categoryGeneral => 'General';

  @override
  String get faq_categoryUsage => 'How to Use';

  @override
  String get faq_categoryAccount => 'Account';

  @override
  String get faq_categoryPet => 'Pet Management';

  @override
  String get faq_q1 => 'Is this app free?';

  @override
  String get faq_a1 =>
      'Basic features of Perch Care are free. Subscribe to Premium for additional features like AI Vision Health Check.';

  @override
  String get faq_q2 => 'How accurate is the AI health analysis?';

  @override
  String get faq_a2 =>
      'AI analysis is for reference only and does not replace professional diagnosis. If your pet has health concerns, please consult a veterinarian.';

  @override
  String get faq_q3 => 'Is my data stored safely?';

  @override
  String get faq_a3 =>
      'All data is encrypted and securely stored on our servers. Your data is restored when you log in on a new device.';

  @override
  String get faq_q4 => 'How do I record weight?';

  @override
  String get faq_a4 =>
      'Go to the Weight tab in the bottom navigation, select a date, and enter the weight in grams.';

  @override
  String get faq_q5 => 'How do I record food and water?';

  @override
  String get faq_a5 =>
      'Tap the food or water card on the Home screen to go to the recording page. Add items and save.';

  @override
  String get faq_q6 => 'What is BHI (Health Index)?';

  @override
  String get faq_a6 =>
      'BHI (Bird Health Index) is a score that combines weight, food, and water records to show your bird\'s overall health status.';

  @override
  String get faq_q7 => 'Can I edit or delete records?';

  @override
  String get faq_a7 =>
      'Yes, tap a food record to edit it. Swipe left on an item to delete it.';

  @override
  String get faq_q8 => 'How do I change the language?';

  @override
  String get faq_a8 =>
      'Go to Profile > Language Settings and choose between Korean, English, or Chinese.';

  @override
  String get faq_q9 => 'How do I link or unlink social accounts?';

  @override
  String get faq_a9 =>
      'Go to Profile > Social Account Linking to manage Google and Apple account connections.';

  @override
  String get faq_q10 => 'What happens to my data if I delete my account?';

  @override
  String get faq_a10 =>
      'All personal information and pet records are permanently deleted and cannot be recovered.';

  @override
  String get faq_q11 => 'How do I add or delete a pet?';

  @override
  String get faq_a11 =>
      'Go to Profile > My Pets. Use the (+) button to add and the (X) button to delete.';

  @override
  String get faq_q12 => 'Which species are supported?';

  @override
  String get faq_a12 =>
      'Currently parrots (budgies, cockatiels, etc.) are supported. Other bird species will be added in the future.';

  @override
  String get faq_q13 => 'Is Android or HarmonyOS supported?';

  @override
  String get faq_a13 =>
      'Currently only iOS is supported. Android and HarmonyOS versions are in development and will be released in the future.';

  @override
  String get faq_categoryPremium => 'Premium';

  @override
  String get faq_q14 => 'What is Premium?';

  @override
  String get faq_a14 =>
      'Premium provides advanced features including unlimited AI Vision Health Check and image-based detailed analysis.';

  @override
  String get faq_q15 => 'How do I use a Premium code?';

  @override
  String get faq_a15 =>
      'Go to Profile > Premium and enter your code in the format PERCH-XXXX-XXXX to activate immediately.';

  @override
  String get faq_q16 => 'What happens to my data when Premium expires?';

  @override
  String get faq_a16 =>
      'Your health check text results are retained after expiration. However, health check images are automatically deleted from the server 90 days after expiration.';

  @override
  String get faq_q17 => 'How do I use AI Vision Health Check?';

  @override
  String get faq_a17 =>
      'Tap the \'AI Health Check\' button on the Home screen, select an analysis type (full body/body part/droppings/food), then take a photo or choose from your album.';

  @override
  String get faq_q18 => 'Which body parts can be analyzed?';

  @override
  String get faq_a18 =>
      'You can analyze full body, eyes, beak, feathers, and feet individually. Droppings analysis and food safety checks are also available.';

  @override
  String get faq_q19 => 'Where can I view health check records?';

  @override
  String get faq_a19 =>
      'Tap the \'History\' button at the top of the AI Health Check screen to view your health check results.';

  @override
  String get faq_q20 => 'How do I use the AI Encyclopedia (chatbot)?';

  @override
  String get faq_a20 =>
      'Tap the AI Encyclopedia banner on the Home screen to open the chat screen where you can ask questions about your bird.';

  @override
  String get faq_q21 => 'Are chat records saved?';

  @override
  String get faq_a21 =>
      'Yes, chat records are securely stored on the server. You can view previous conversations even after logging out and back in.';

  @override
  String get faq_q22 => 'Where can I check breed-specific standard weight?';

  @override
  String get faq_a22 =>
      'Standard weight ranges for your breed are displayed on the weight chart. Set your pet\'s breed in the pet profile.';

  @override
  String get premium_sectionTitle => 'Premium';

  @override
  String get premium_title => 'Enter Premium Code';

  @override
  String get premium_badgeFree => 'Free';

  @override
  String get premium_badgePremium => 'Premium';

  @override
  String premium_expiresAt(String date) {
    return 'Until $date';
  }

  @override
  String get premium_enterCode => 'Enter your premium code';

  @override
  String get premium_benefitsTitle => 'Premium Benefits';

  @override
  String get premium_benefit1 => 'Unlimited AI vision health checks';

  @override
  String get premium_benefit2 => 'Image-based health analysis';

  @override
  String get premium_benefit3 => 'Early health abnormality detection';

  @override
  String get premium_codeInputTitle => 'Premium Code';

  @override
  String get premium_codeInputHint => 'PERCH-XXXX-XXXX';

  @override
  String get premium_activateButton => 'Activate Code';

  @override
  String get premium_invalidCodeFormat =>
      'Invalid code format. (PERCH-XXXX-XXXX)';

  @override
  String get premium_activationFailed =>
      'Code activation failed. Please check your code.';

  @override
  String get premium_activationError =>
      'An error occurred during activation. Please try again.';

  @override
  String get premium_rateLimitExceeded =>
      'Too many requests. Please try again later.';

  @override
  String get premium_activationSuccessTitle => 'Premium Activated!';

  @override
  String premium_activationSuccessContent(String date) {
    return 'Premium service is available until $date.';
  }

  @override
  String get premium_activationSuccessContentNoDate =>
      'Premium service has been activated.';

  @override
  String get premium_upgradeToPremium => 'Upgrade to Premium';

  @override
  String get premium_healthCheckBlocked =>
      'This is a premium-only feature.\nPlease upgrade to Premium.';

  @override
  String get premium_healthCheckBlockedTitle => 'Premium Feature';

  @override
  String get hc_title => 'AI Health Check';

  @override
  String get hc_photoSubtitle => 'Check health status with just one photo';

  @override
  String get hc_selectTarget => 'Please select an analysis target';

  @override
  String get hc_analyze => 'Analyze';

  @override
  String get hc_modeFullBody => 'Full Body';

  @override
  String get hc_modeFullBodyDesc =>
      'Analyze appearance by photographing the full body';

  @override
  String get hc_modePartSpecific => 'Part-Specific';

  @override
  String get hc_modePartSpecificDesc =>
      'Analyze specific parts such as eyes, beak, feathers, feet';

  @override
  String get hc_modeDroppings => 'Droppings Analysis';

  @override
  String get hc_modeDroppingsDesc =>
      'Check health status through droppings photos';

  @override
  String get hc_modeFood => 'Food Safety';

  @override
  String get hc_modeFoodDesc => 'Check if food is safe to feed through photos';

  @override
  String get hc_partEye => 'Eye';

  @override
  String get hc_partBeak => 'Beak';

  @override
  String get hc_partFeather => 'Feather';

  @override
  String get hc_partFoot => 'Foot';

  @override
  String get hc_imageSizeExceeded => 'Image size exceeds 10MB';

  @override
  String hc_imagePickError(String error) {
    return 'Error while selecting image: $error';
  }

  @override
  String get hc_takePhoto => 'Take Photo';

  @override
  String get hc_selectFromAlbum => 'Select from Album';

  @override
  String get hc_photoHint => 'Take a photo or\nselect from album';

  @override
  String get hc_registerPetFirst => 'Please register your pet first';

  @override
  String get hc_analysisError =>
      'An error occurred during analysis.\nPlease try again.';

  @override
  String get hc_cancelAnalysis => 'Cancel Analysis';

  @override
  String get hc_cancelAnalysisConfirm => 'Cancel the analysis?';

  @override
  String get hc_continueAnalysis => 'Continue';

  @override
  String get hc_analyzing => 'Analyzing...';

  @override
  String get hc_aiAnalyzing => 'AI is analyzing the image';

  @override
  String get hc_analysisErrorTitle => 'An error occurred during analysis';

  @override
  String get hc_retry => 'Retry';

  @override
  String get hc_goBack => 'Go Back';

  @override
  String get hc_resultTitle => 'Analysis Results';

  @override
  String get hc_analysisItems => 'Analysis Items';

  @override
  String get hc_recommendations => 'Recommendations';

  @override
  String get hc_overallStatus => 'Overall Status';

  @override
  String get hc_confidence => 'Confidence';

  @override
  String get hc_vetVisitRecommended => 'Veterinary visit recommended';

  @override
  String get hc_possibleCauses => 'Possible Causes';

  @override
  String get hc_possibleCausesPrefix => 'Possible causes: ';

  @override
  String get hc_nutritionBalance => 'Nutrition Balance';

  @override
  String get hc_goHome => 'Go Home';

  @override
  String get hc_recheckButton => 'Check Again';

  @override
  String hc_colorTexture(String color, String texture) {
    return 'Color: $color, Texture: $texture';
  }

  @override
  String get hc_severityNormal => 'Normal';

  @override
  String get hc_severityCaution => 'Caution';

  @override
  String get hc_severityWarning => 'Warning';

  @override
  String get hc_severityCritical => 'Critical';

  @override
  String get hc_severityUnknown => 'Check Required';

  @override
  String get hc_areaFeather => 'Feather Condition';

  @override
  String get hc_areaPosture => 'Posture/Balance';

  @override
  String get hc_areaEye => 'Eye Condition';

  @override
  String get hc_areaBeak => 'Beak Condition';

  @override
  String get hc_areaFoot => 'Feet/Claws';

  @override
  String get hc_areaBodyShape => 'Body Shape';

  @override
  String get hc_areaFeces => 'Feces';

  @override
  String get hc_areaUrates => 'Urates';

  @override
  String get hc_areaUrine => 'Urine';

  @override
  String get hc_areaInjuryDetected => 'Injury Detected';

  @override
  String get hc_firstAidTitle => 'Emergency First Aid';

  @override
  String get hc_notesHint => 'Describe any injuries or incidents (optional)';

  @override
  String get hc_notesHintFullBody =>
      'Describe overall health condition or any concerns (optional)';

  @override
  String get hc_notesHintDroppings =>
      'Describe color, shape, frequency of droppings, etc. (optional)';

  @override
  String get hc_notesHintFood =>
      'Describe food type, amount eaten, appetite changes, etc. (optional)';

  @override
  String get ai_petInfoPrefix => 'Name';

  @override
  String get ai_breedPrefix => 'Breed';

  @override
  String get ai_agePrefix => 'Age';

  @override
  String get ai_birthdayPrefix => 'Birthday';

  @override
  String get ai_genderMale => 'Male';

  @override
  String get ai_genderFemale => 'Female';

  @override
  String get ai_genderUnknown => 'Gender unknown';

  @override
  String get ai_petContextInstruction =>
      'Refer to the parrot information selected from multiple profiles.';

  @override
  String get ai_petContextAdvice =>
      'Provide customized advice based on the above parrot conditions, especially breed.';

  @override
  String ai_ageYears(int years) {
    return '$years years old';
  }

  @override
  String ai_ageMonths(int months) {
    return '$months months';
  }

  @override
  String get ai_ageLessThanMonth => 'Less than 1 month';

  @override
  String get hc_history => 'History';

  @override
  String get hc_historyTitle => 'Health Check History';

  @override
  String get hc_historyEmpty => 'No health check records yet';

  @override
  String get hc_historyEmptyDesc =>
      'Check your bird\'s health with AI Health Check';

  @override
  String get hc_savedSuccessfully => 'Results saved';

  @override
  String get hc_deleteConfirm => 'Delete this record?';

  @override
  String get hc_deleteSuccess => 'Record deleted';

  @override
  String get hc_dateToday => 'Today';

  @override
  String get hc_dateYesterday => 'Yesterday';

  @override
  String get hc_dateLast7Days => 'Last 7 days';

  @override
  String get hc_dateEarlier => 'Earlier';

  @override
  String get premium_featureLockedTitle => 'Premium Feature';

  @override
  String get premium_featureLockedMessage =>
      'AI Vision Health Check is a premium-only feature.\n\nVision AI models are costly to run, and we appreciate your understanding.\nActivate a premium code for unlimited access.';

  @override
  String get premium_activateNow => 'Activate Premium';

  @override
  String get premium_maybeLater => 'Maybe Later';

  @override
  String get chatbot_premiumBanner =>
      'Get more detailed and accurate answers with Premium';

  @override
  String get chatbot_premiumUpgrade => 'Upgrade';

  @override
  String get paywall_title => 'Premium';

  @override
  String get paywall_headline =>
      'Get a more accurate picture of\nyour bird\'s health';

  @override
  String get paywall_benefit1 => 'Unlimited AI Vision health checks';

  @override
  String get paywall_benefit2 => 'Record-based personalized AI insights';

  @override
  String get paywall_benefit3 => 'Early detection of health anomalies';

  @override
  String get paywall_planMonthly => 'Monthly';

  @override
  String get paywall_planYearly => 'Yearly';

  @override
  String get paywall_yearlyDiscount => 'Best value';

  @override
  String paywall_yearlyPerMonth(String price) {
    return '$price/mo';
  }

  @override
  String get paywall_ctaButton => 'Start Premium';

  @override
  String get paywall_restore => 'Restore Purchases';

  @override
  String get paywall_promoCode => 'Enter promo code';

  @override
  String get paywall_purchaseSuccessTitle => 'Premium Activated!';

  @override
  String get paywall_purchaseSuccessContent =>
      'You now have access to all premium features.';

  @override
  String get paywall_purchaseFailed => 'Purchase failed. Please try again.';

  @override
  String get paywall_restoreSuccess => 'Purchases restored successfully.';

  @override
  String get paywall_restoreNoSubscription => 'No subscription to restore.';

  @override
  String get paywall_restoreFailed => 'Failed to restore purchases.';

  @override
  String get paywall_loading => 'Processing...';

  @override
  String get paywall_storeUnavailable => 'Store is not available.';

  @override
  String get paywall_productsNotFound => 'Unable to load product information.';

  @override
  String get paywall_alreadyPremium => 'You are already a Premium user.';

  @override
  String paywall_alreadyPremiumExpires(String date) {
    return 'Available until $date';
  }

  @override
  String quotaBadge_normal(int count) {
    return '$count left today';
  }

  @override
  String get quotaBadge_exhausted => 'Daily limit reached';

  @override
  String get quotaBadge_upgrade => 'Upgrade';

  @override
  String get aiEncyclopedia_quotaExhausted =>
      'You\'ve used all free queries for today. Upgrade to Premium for unlimited access.';

  @override
  String get aiEncyclopedia_quotaExhaustedHint =>
      'Daily limit reached · Upgrade to Premium';

  @override
  String get healthCheck_freeTrialBadge => '1 free trial';

  @override
  String get healthCheck_trialExhaustedTitle => 'Free trial completed';

  @override
  String get healthCheck_trialExhaustedMessage =>
      'You\'ve already used your free trial.\n\nSubscribe to Premium for unlimited AI Vision health checks.';

  @override
  String get report_shareFailed => 'Failed to create share link.';

  @override
  String get report_shareHealth => 'Share Health Report';

  @override
  String get report_vetSummary => 'Vet Visit Summary';

  @override
  String get report_vetSummaryTitle => 'Vet Visit Summary';

  @override
  String get report_vetSummaryDesc =>
      'Generate a shareable link summarizing\nyour bird\'s health data from the last 30 days.';

  @override
  String get report_vetFeatureWeight => 'Weight trends';

  @override
  String get report_vetFeatureChecks => 'AI health check summary';

  @override
  String get report_vetFeatureNotes => 'Behavior notes & daily records';

  @override
  String get report_vetShareButton => 'Share Summary Link';

  @override
  String get home_healthSummaryTitle => 'Health Change Summary';

  @override
  String get home_healthSummaryWeightChange => 'Weight Change';

  @override
  String get home_healthSummaryAbnormal => 'Abnormal Findings (30d)';

  @override
  String get home_healthSummaryFoodConsistency => 'Feeding Consistency';

  @override
  String get home_healthSummaryWaterConsistency => 'Water Consistency';

  @override
  String get home_healthSummaryUpgrade => 'Upgrade to Premium';

  @override
  String get home_insightsTitle => 'Weekly Insights';

  @override
  String get home_insightsEmpty => 'No insights yet';

  @override
  String get home_insightsRecommendations => 'Recommendations';

  @override
  String get home_insightsUpgrade =>
      'Upgrade to Premium to receive\nweekly health insights';

  @override
  String get dailyRecord_title => 'Daily Record';

  @override
  String get dailyRecord_mood => 'Mood';

  @override
  String get dailyRecord_activity => 'Activity';

  @override
  String get dailyRecord_notes => 'Notes';

  @override
  String get dailyRecord_notesHint =>
      'Record anything notable about your bird today';

  @override
  String get dailyRecord_moodGreat => 'Great';

  @override
  String get dailyRecord_moodGood => 'Good';

  @override
  String get dailyRecord_moodNormal => 'Normal';

  @override
  String get dailyRecord_moodBad => 'Bad';

  @override
  String get dailyRecord_moodSick => 'Sick';

  @override
  String get dailyRecord_saved => 'Daily record saved';

  @override
  String get dailyRecord_deleted => 'Daily record deleted';

  @override
  String get dailyRecord_saveError => 'Failed to save daily record';

  @override
  String get dailyRecord_deleteError => 'Failed to delete daily record';

  @override
  String get weightDetail_monthDailyRecord => 'Daily Records This Month';

  @override
  String weightDetail_dateDailyRecord(int month, int day) {
    return 'Daily Record for $month/$day';
  }

  @override
  String get weightDetail_noDailyRecord => 'No daily records yet';

  @override
  String get weightDetail_noDailyRecordOnDate =>
      'No daily records for this date';

  @override
  String get weightDetail_addDailyRecordHint =>
      'Tap the button below to add a record';

  @override
  String get btn_addSchedule => 'Add Schedule';

  @override
  String get btn_addDailyRecord => 'Add Daily Record';

  @override
  String get profileSetup_title => 'Profile Setup';

  @override
  String get profileSetup_phoneHint => 'Enter phone number';

  @override
  String get profileSetup_complete => 'Complete';

  @override
  String get profileSetup_saveError => 'Error saving profile.';

  @override
  String get profileSetup_genderSelectTitle => 'Select gender';

  @override
  String get profileSetup_genderMale => 'Male';

  @override
  String get profileSetup_genderFemale => 'Female';

  @override
  String get profileSetup_doneTitle => 'Setup Complete';

  @override
  String get profileSetup_doneMessage => 'Setup is complete!';

  @override
  String get profileSetup_startRecording => 'Start Recording!';

  @override
  String get timePicker_title => 'Select Time';

  @override
  String get timePicker_confirm => 'Confirm';

  @override
  String get country_selectTitle => 'Select Country';
}
