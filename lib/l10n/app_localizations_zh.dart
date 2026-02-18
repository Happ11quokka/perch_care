// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get common_save => '保存';

  @override
  String get common_cancel => '取消';

  @override
  String get common_confirm => '确认';

  @override
  String get common_close => '关闭';

  @override
  String get common_delete => '删除';

  @override
  String get common_edit => '编辑';

  @override
  String get common_later => '稍后再说';

  @override
  String get common_view => '查看';

  @override
  String get common_noData => '暂无数据';

  @override
  String get common_loading => '加载中...';

  @override
  String get common_saveSuccess => '已保存成功。';

  @override
  String common_saveError(String error) {
    return '保存时发生错误: $error';
  }

  @override
  String get common_updated => '修改成功。';

  @override
  String get common_registered => '注册成功。';

  @override
  String get common_collapse => '收起';

  @override
  String common_showAll(int count) {
    return '查看全部 ($count)';
  }

  @override
  String get pet_loadError => '加载宠物信息失败。';

  @override
  String get onboarding_title => '很高兴认识你！';

  @override
  String get onboarding_description => '不仅仅是简单的记录，\n通过AI分析更深入地了解鹦鹉的状态。';

  @override
  String get btn_start => '开始使用';

  @override
  String get login_title => '登录';

  @override
  String get login_kakao => '使用Kakao登录';

  @override
  String get login_google => '使用Google登录';

  @override
  String get login_apple => '使用Apple登录';

  @override
  String get login_button => '登录';

  @override
  String get login_notMember => '还不是会员？';

  @override
  String get login_signup => '注册';

  @override
  String get login_saveId => '记住账号';

  @override
  String get login_findIdPassword => '找回账号/密码';

  @override
  String get input_email => '邮箱';

  @override
  String get input_email_hint => '请输入邮箱';

  @override
  String get input_password => '密码';

  @override
  String get input_password_hint => '请输入密码';

  @override
  String get input_name => '姓名';

  @override
  String get input_name_hint => '请输入姓名';

  @override
  String get dialog_kakaoLoginTitle => 'Kakao登录说明';

  @override
  String get dialog_kakaoLoginContent1 => '由于Kakao政策限制，无法直接登录。';

  @override
  String get dialog_kakaoLoginContent2 =>
      '请先使用邮箱注册，然后在个人中心绑定Kakao账号，之后即可使用Kakao登录。';

  @override
  String get dialog_goSignup => '去注册';

  @override
  String get signup_title => '注册';

  @override
  String get signup_button => '注册';

  @override
  String get signup_alreadyMember => '已有账号？';

  @override
  String get signup_completeTitle => '注册成功';

  @override
  String get signup_completeMessage => '注册成功！\n登录后即可使用服务。';

  @override
  String get terms_agreeAll => '全部同意';

  @override
  String get terms_requiredTerms => '[必选] 同意服务条款';

  @override
  String get terms_requiredPrivacy => '[必选] 同意隐私政策';

  @override
  String get terms_optionalMarketing => '[可选] 同意接收营销信息';

  @override
  String get terms_termsOfService => '服务条款';

  @override
  String get terms_privacyPolicy => '隐私政策';

  @override
  String get terms_sectionTitle => '条款与政策';

  @override
  String get forgot_title => '找回密码';

  @override
  String get forgot_description => '请输入注册时使用的邮箱。\n我们将发送密码重置验证码。';

  @override
  String get btn_sendCode => '发送验证码';

  @override
  String get forgot_codeTitle => '输入验证码';

  @override
  String get forgot_codeDescription => '验证码已发送给您。\n请在2分钟内输入收到的验证码。';

  @override
  String forgot_codeSentTo(String destination) {
    return '验证码已发送至$destination。';
  }

  @override
  String forgot_timeRemaining(String time) {
    return '剩余时间：$time';
  }

  @override
  String get btn_resendCode => '重新发送验证码';

  @override
  String get forgot_newPasswordTitle => '设置新密码';

  @override
  String get forgot_newPasswordDescription => '请输入新密码，\n不能使用之前使用过的密码。';

  @override
  String get input_newPassword => '新密码';

  @override
  String get input_confirmPassword => '确认密码';

  @override
  String get btn_resetComplete => '完成重置';

  @override
  String get home_monthlyUnit => '月度';

  @override
  String get home_weeklyUnit => '周度';

  @override
  String get home_wciHealthStatus => 'WCI* 健康状态';

  @override
  String home_updatedAgo(int minutes) {
    return '$minutes分钟前更新';
  }

  @override
  String home_enterDataPrompt(String petName) {
    return '输入数据查看$petName的';
  }

  @override
  String get home_checkStatus => '健康状态。';

  @override
  String home_level(int level) {
    return '第$level级';
  }

  @override
  String get home_weight => '体重';

  @override
  String get home_weightHint => '请输入体重';

  @override
  String get home_food => '食物';

  @override
  String get home_foodHint => '请输入进食量';

  @override
  String get home_water => '饮水';

  @override
  String get home_waterHint => '请输入饮水量';

  @override
  String get home_todayHealthSignal => '今日';

  @override
  String get home_healthSignal => '健康信号';

  @override
  String home_monthFormat(int month) {
    return '$month月';
  }

  @override
  String home_weekFormat(int week) {
    return '第$week周';
  }

  @override
  String get wci_level1 => '身体较轻且偏瘦。\n建议检查一下食量和身体状况。';

  @override
  String get wci_level2 => '肋骨不可见，但轻触可感觉到。\n侧面看腹部略显凹陷。';

  @override
  String get wci_level3 => '整体体型稳定。\n保持现有习惯并继续观察。';

  @override
  String get wci_level4 => '身体整体看起来较圆润。\n建议检查一下食量和零食。';

  @override
  String get wci_level5 => '整体看起来较重。\n建议调整饮食和活动量。';

  @override
  String get weight_title => '体重';

  @override
  String get weight_wciHealthStatus => 'WCI 健康状态';

  @override
  String get weight_inputWeight => '输入体重';

  @override
  String get weight_inputHint => '例如: 58.3';

  @override
  String get weight_formula => '计算公式';

  @override
  String get weight_formulaText => 'WCI(%) = (当前体重 - 基准体重) ÷ 基准体重 × 100';

  @override
  String get weight_calculation => '计算过程';

  @override
  String get weight_noData => '暂无数据。';

  @override
  String get weight_level0Title => 'Level 0';

  @override
  String get weight_level0Desc => '请输入体重';

  @override
  String get weight_level1Title => 'Level 1 | 偏轻';

  @override
  String get weight_level1Desc => '身体很轻。请检查食量和身体状况。';

  @override
  String get weight_level2Title => 'Level 2 | 略轻';

  @override
  String get weight_level2Desc => '体型偏瘦。保持现有习惯并观察。';

  @override
  String get weight_level3Title => 'Level 3 | 理想状态';

  @override
  String get weight_level3Desc => '体重处于最佳范围。建议保持当前状态。';

  @override
  String get weight_level4Title => 'Level 4 | 略重';

  @override
  String get weight_level4Desc => '身体看起来有些沉重。请检查饮食平衡。';

  @override
  String get weight_level5Title => 'Level 5 | 偏重';

  @override
  String get weight_level5Desc => '体重增加较多。需要调整饮食和活动。';

  @override
  String get weight_unitGram => '克';

  @override
  String get weightDetail_title => '记录';

  @override
  String get weightDetail_headerLine1 => '坚持记录';

  @override
  String weightDetail_headerLine2(String petName) {
    return '一眼查看$petName的体重变化！';
  }

  @override
  String get weightDetail_subLine1 => '立即记录，';

  @override
  String get weightDetail_subLine2 => '轻松管理宝贝的健康状态。';

  @override
  String get weightDetail_toggleWeek => '周';

  @override
  String get weightDetail_toggleMonth => '月';

  @override
  String weightDetail_recordSummary(String petName, int days) {
    return '$petName共记录$days天体重';
  }

  @override
  String weightDetail_yearMonth(int year, int month) {
    return '$year年$month月';
  }

  @override
  String weightDetail_monthChartLabel(int month) {
    return '$month月';
  }

  @override
  String schedule_dateDisplay(int month, int day, String weekday) {
    return '$month月$day日（$weekday）';
  }

  @override
  String get weightDetail_noPet => '暂无活跃的宠物。请先添加宠物。';

  @override
  String get weightDetail_noSchedule => '暂无日程';

  @override
  String get weightDetail_addScheduleHint => '点击下方按钮添加日程';

  @override
  String get weightDetail_monthSchedule => '本月日程';

  @override
  String get weightDetail_noWeightRecord => '本月暂无体重记录';

  @override
  String weightDetail_monthWeightRecord(int month) {
    return '$month月体重记录';
  }

  @override
  String get btn_addRecord => '添加记录';

  @override
  String get weightDetail_today => '今天';

  @override
  String get profile_title => '个人中心';

  @override
  String get profile_myPets => '我的宠物';

  @override
  String get profile_addNewPet => '添加新宠物';

  @override
  String get profile_socialAccounts => '社交账号绑定';

  @override
  String get profile_link => '绑定';

  @override
  String get profile_unlink => '解绑';

  @override
  String get profile_accountManagement => '账号管理';

  @override
  String get profile_logout => '退出登录';

  @override
  String get profile_deleteAccount => '注销账号';

  @override
  String get profile_noSpecies => '无品种信息';

  @override
  String get profile_noAge => '无年龄信息';

  @override
  String profile_ageFormat(int years, int months, int days) {
    return '$years年$months月$days天';
  }

  @override
  String get dialog_unlinkTitle => '解绑社交账号';

  @override
  String dialog_unlinkContent(String provider) {
    return '确定要解绑$provider账号吗？';
  }

  @override
  String get dialog_logoutTitle => '退出登录';

  @override
  String get dialog_logoutContent => '确定要退出登录吗？';

  @override
  String get dialog_deleteAccountTitle => '注销账号';

  @override
  String get dialog_deleteAccountContent => '注销后所有数据将被删除且无法恢复。\n确定要注销吗？';

  @override
  String get dialog_delete => '注销';

  @override
  String get pet_profile => '宠物资料';

  @override
  String get pet_name_hint => '请输入名字';

  @override
  String get pet_gender_hint => '请选择性别';

  @override
  String get pet_weight_hint => '体重';

  @override
  String get pet_birthday_hint => '生日';

  @override
  String get pet_adoptionDate_hint => '成为家人的日子';

  @override
  String get pet_species_hint => '品种';

  @override
  String get pet_growthStage_hint => '请选择成长阶段';

  @override
  String get pet_genderMale => '雄性';

  @override
  String get pet_genderFemale => '雌性';

  @override
  String get pet_genderUnknown => '未知';

  @override
  String get pet_growthRapid => '快速成长期';

  @override
  String get pet_growthPost => '后续成长期';

  @override
  String get pet_growthAdult => '成年期';

  @override
  String get dialog_selectGender => '选择性别';

  @override
  String get dialog_selectGrowthStage => '选择成长阶段';

  @override
  String get error_googleLogin => 'Google登录时发生错误。';

  @override
  String get error_appleLogin => 'Apple登录时发生错误。';

  @override
  String get error_kakaoLogin => 'Kakao登录时发生错误。';

  @override
  String get error_login => '登录时发生错误。';

  @override
  String get error_loginRetry => '登录时发生错误，请重试。';

  @override
  String get error_sendCode => '发送验证码时发生错误。';

  @override
  String get error_invalidCode => '验证码不正确，请重新确认。';

  @override
  String get error_passwordChange => '修改密码时发生错误。';

  @override
  String get error_unexpected => '发生意外错误，请重试。';

  @override
  String error_saveFailed(String error) {
    return '保存时发生错误：$error';
  }

  @override
  String get error_loadPet => '加载宠物信息失败。';

  @override
  String get error_deleteAccount => '注销失败，请重试。';

  @override
  String get error_linkGoogle => '绑定Google账号失败。';

  @override
  String get error_linkApple => '绑定Apple账号失败。';

  @override
  String get error_linkKakao => '绑定Kakao账号失败。';

  @override
  String error_unlinkFailed(String provider) {
    return '解绑$provider账号失败。';
  }

  @override
  String get snackbar_codeResent => '验证码已重新发送。';

  @override
  String get snackbar_passwordChanged => '密码修改成功。';

  @override
  String get snackbar_saved => '已保存。';

  @override
  String get snackbar_updated => '已更新。';

  @override
  String get snackbar_registered => '已注册。';

  @override
  String get snackbar_googleLinked => 'Google账号已绑定。';

  @override
  String get snackbar_appleLinked => 'Apple账号已绑定。';

  @override
  String get snackbar_kakaoLinked => 'Kakao账号已绑定。';

  @override
  String snackbar_unlinked(String provider) {
    return '$provider账号已解绑。';
  }

  @override
  String get validation_enterEmail => '请输入邮箱。';

  @override
  String get validation_invalidEmail => '请输入正确的邮箱格式。';

  @override
  String get validation_enterPassword => '请输入密码。';

  @override
  String get validation_passwordMin8 => '密码至少需要8个字符';

  @override
  String get validation_enterName => '请输入姓名';

  @override
  String get validation_checkInput => '请检查输入信息';

  @override
  String get validation_enterNewPassword => '请输入新密码。';

  @override
  String get validation_confirmPassword => '请再次输入密码。';

  @override
  String get validation_passwordMismatch => '密码不一致。';

  @override
  String get datetime_weekday_mon => '一';

  @override
  String get datetime_weekday_tue => '二';

  @override
  String get datetime_weekday_wed => '三';

  @override
  String get datetime_weekday_thu => '四';

  @override
  String get datetime_weekday_fri => '五';

  @override
  String get datetime_weekday_sat => '六';

  @override
  String get datetime_weekday_sun => '日';

  @override
  String datetime_dateFormat(int year, int month, int day, String weekday) {
    return '$year年$month月$day日（周$weekday）';
  }

  @override
  String datetime_dateShort(int month, int day, String weekday) {
    return '$month/$day（周$weekday）';
  }

  @override
  String get social_kakao => 'Kakao';

  @override
  String get social_google => 'Google';

  @override
  String get social_apple => 'Apple';

  @override
  String get profile_user => '用户';

  @override
  String get profile_userSuffix => '';

  @override
  String get profile_languageSettings => '语言设置';

  @override
  String get profile_languageSelect => '选择语言';

  @override
  String get profile_deviceDefault => '设备默认';

  @override
  String get profile_deviceDefaultSubtitle => '跟随系统语言';

  @override
  String get profile_zeroDay => '0天';

  @override
  String get bhi_title => '健康分数';

  @override
  String get bhi_noDataTitle => '暂无健康数据';

  @override
  String get bhi_noDataSubtitle => '请输入体重、食物和饮水数据';

  @override
  String get bhi_scoreComposition => '分数构成';

  @override
  String get bhi_healthScore => 'BHI 健康分数';

  @override
  String get bhi_scoreMax => '/100';

  @override
  String get bhi_noData => '无数据';

  @override
  String get bhi_wciLevel => 'WCI 等级';

  @override
  String get bhi_growthStage => '成长阶段';

  @override
  String bhi_stageNumber(int stage) {
    return '第$stage阶段';
  }

  @override
  String get bhi_accuracyHint => '记录时间越长，健康分数越准确。';

  @override
  String bhi_baseDate(String date) {
    return '基准日期: $date';
  }

  @override
  String get bhi_statusHealthy => '健康状态';

  @override
  String get bhi_statusStable => '稳定状态';

  @override
  String get bhi_statusCaution => '需要注意';

  @override
  String get bhi_statusManagement => '需要护理';

  @override
  String get bhi_statusInsufficient => '数据不足';

  @override
  String get bhi_descHealthy => '体重、食物、饮水都很好。\n请保持当前习惯。';

  @override
  String get bhi_descStable => '整体还可以，但\n请检查一些项目。';

  @override
  String get bhi_descCaution => '某些项目检测到变化。\n请检查数据。';

  @override
  String get bhi_descManagement => '健康指标偏低。\n请检查食物和饮水量。';

  @override
  String get bhi_descInsufficient => '输入数据后可查看健康分数。';

  @override
  String get bhi_growthAdult => '成年期';

  @override
  String get bhi_growthPostGrowth => '后续成长期';

  @override
  String get bhi_growthRapidGrowth => '快速成长期';

  @override
  String get food_title => '食物';

  @override
  String get food_addTitle => '添加食物';

  @override
  String get food_editTitle => '编辑食物';

  @override
  String get food_nameLabel => '食物名称';

  @override
  String get food_totalIntake => '总摄入量(g)';

  @override
  String get food_targetAmount => '目标量(g)';

  @override
  String get food_intakeCount => '摄入次数';

  @override
  String get food_routine => '喂食习惯';

  @override
  String get food_addFood => '登记正在吃的食物';

  @override
  String get food_dailyTarget => '每日目标';

  @override
  String food_recommendedRange(int min, int max) {
    return '推荐: $min~${max}g/天';
  }

  @override
  String get food_dailyCount => '每日摄入次数';

  @override
  String food_perMeal(int amount) {
    return '每次: ${amount}g';
  }

  @override
  String food_timesCount(int count) {
    return '$count次';
  }

  @override
  String get pet_defaultName => '鸟';

  @override
  String get wciIndex_title => '什么是WCI？';

  @override
  String get wciIndex_description => '一个健康指标，以百分比形式显示\n饮食习惯变化对体重的影响。';

  @override
  String get wciIndex_calculationMethod => '计算方法';

  @override
  String get wciIndex_levelCriteria => 'WCI 5级标准';

  @override
  String get chatbot_title => '智能助手';

  @override
  String get chatbot_clearHistory => '清除聊天记录';

  @override
  String get chatbot_clearHistoryConfirm => '所有聊天记录将被删除。是否继续？';

  @override
  String get chatbot_historyCleared => '聊天记录已清除。';

  @override
  String get chatbot_welcomeTitle => '你好！我是鹦鹉博士！';

  @override
  String get chatbot_welcomeDescription => '如果您对鹦鹉有任何疑问，\n请随时问我！';

  @override
  String get chatbot_preparingAnswer => '正在准备回答...';

  @override
  String get chatbot_aiError => 'AI响应失败，请稍后重试。';

  @override
  String get chatbot_inputHint => '请输入您的问题';

  @override
  String get chatbot_suggestion1 => '初期维生素摄入量';

  @override
  String get chatbot_suggestion2 => '换羽期护理方法';

  @override
  String get chatbot_suggestion3 => '健康检查频率';

  @override
  String get chatbot_suggestion4 => '体重记录技巧';

  @override
  String chatbot_aiCallFailed(String error) {
    return 'AI调用失败：$error';
  }

  @override
  String get water_title => '饮水';

  @override
  String get water_inputTitle => '饮水量输入';

  @override
  String get water_totalIntake => '总饮水量(ml)';

  @override
  String get water_intakeCount => '饮水次数';

  @override
  String get water_routine => '饮水习惯';

  @override
  String get water_water => '水';

  @override
  String get water_dailyTarget => '每日饮水目标';

  @override
  String water_recommendedRange(String amount) {
    return '推荐：${amount}ml/天';
  }

  @override
  String get water_dailyCount => '每日饮水次数';

  @override
  String water_perDrink(String amount) {
    return '每次：${amount}ml';
  }

  @override
  String water_timesCount(int count) {
    return '$count次';
  }

  @override
  String get weight_bodyWeight => '体重*';

  @override
  String get weight_addStickerHint => '点击这里添加贴纸。';

  @override
  String get weight_inputLabel => '输入体重 (g)';

  @override
  String get weight_recordSuccess => '今日体重已记录！';

  @override
  String get weight_bcs1 => '骨骼容易触摸到，侧面看非常瘦。\n请增加营养。';

  @override
  String get weight_bcs2 => '肋骨容易触摸到，体型较瘦。\n体重偏低，建议增加食量。';

  @override
  String get weight_bcs3 => '肋骨不可见但轻触可感觉到。\n侧面看腹部略显凹陷。';

  @override
  String get weight_bcs4 => '可以摸到肋骨但有轻微脂肪层。\n侧面看起来较圆润，体重略有增加。';

  @override
  String get weight_bcs5 => '肋骨难以触摸，侧面看起来圆润。\n请减少食量并增加活动量。';

  @override
  String get validation_enterWeight => '请输入体重。';

  @override
  String get validation_enterValidNumber => '请输入正确的数字。';

  @override
  String get validation_weightGreaterThanZero => '体重必须大于0。';

  @override
  String get error_noPetFound => '未找到活跃的宠物。';

  @override
  String datetime_lunar(int month, int day) {
    return '农历$month月$day日';
  }

  @override
  String get datetime_weekdayFull_sun => '星期日';

  @override
  String get datetime_weekdayFull_mon => '星期一';

  @override
  String get datetime_weekdayFull_tue => '星期二';

  @override
  String get datetime_weekdayFull_wed => '星期三';

  @override
  String get datetime_weekdayFull_thu => '星期四';

  @override
  String get datetime_weekdayFull_fri => '星期五';

  @override
  String get datetime_weekdayFull_sat => '星期六';

  @override
  String datetime_minutes(int minutes) {
    return '$minutes分钟';
  }

  @override
  String datetime_seconds(int seconds) {
    return '$seconds秒';
  }

  @override
  String get notification_title => '通知';

  @override
  String get notification_markAllRead => '全部已读';

  @override
  String get notification_empty => '暂无通知';

  @override
  String get notification_deleteError => '删除时发生错误。';

  @override
  String get notification_justNow => '刚刚';

  @override
  String notification_minutesAgo(int minutes) {
    return '$minutes分钟前';
  }

  @override
  String notification_hoursAgo(int hours) {
    return '$hours小时前';
  }

  @override
  String notification_daysAgo(int days) {
    return '$days天前';
  }

  @override
  String get schedule_saveError => '保存日程时发生错误。';

  @override
  String get schedule_deleted => '日程已删除。';

  @override
  String get schedule_deleteError => '删除日程时发生错误。';

  @override
  String schedule_reminderMinutes(int minutes) {
    return '$minutes分钟前';
  }

  @override
  String get btn_save => '保存';

  @override
  String get btn_saveRecord => '保存记录';

  @override
  String get error_network => '请检查网络连接。';

  @override
  String get error_server => '服务器出现临时问题，请稍后重试。';

  @override
  String get error_authRequired => '需要登录。';

  @override
  String get error_conflict => '该信息已注册。';

  @override
  String get error_invalidData => '请重新检查输入信息。';

  @override
  String get error_notFound => '找不到请求的信息。';

  @override
  String get error_savePetFailed => '保存宠物信息失败，请重试。';

  @override
  String get error_saveWeightFailed => '保存体重记录失败，请重试。';

  @override
  String get coach_wciCard_title => '健康状态';

  @override
  String get coach_wciCard_body => '在这里查看WCI健康状态。\n数据越多越准确！';

  @override
  String get coach_weightCard_title => '体重记录';

  @override
  String get coach_weightCard_body => '在这里记录体重！\n每天记录可以追踪健康变化。';

  @override
  String get coach_foodCard_title => '食物记录';

  @override
  String get coach_foodCard_body => '在这里记录食物摄入量。\n有助于准确的健康分析。';

  @override
  String get coach_healthSignalCard_title => '今日健康信号';

  @override
  String get coach_healthSignalCard_body => '查看AI分析的健康信号。';

  @override
  String get coach_waterCard_title => '饮水记录';

  @override
  String get coach_waterCard_body => '在这里记录饮水量。\n水分摄入也是健康管理的重要因素。';

  @override
  String get coach_recordsTab_title => '记录选项卡';

  @override
  String get coach_recordsTab_body => '在这里一目了然地查看\n体重变化和日程。';

  @override
  String get coach_chatbotTab_title => '鹦鹉博士';

  @override
  String get coach_chatbotTab_body => '对鹦鹉有疑问？\n问问AI鹦鹉博士吧！';

  @override
  String get coach_recordToggle_title => '周期切换';

  @override
  String get coach_recordToggle_body => '点击周/月按钮查看不同时期的体重变化。';

  @override
  String get coach_recordChart_title => '体重图表';

  @override
  String get coach_recordChart_body => '在图表中一目了然地查看体重趋势。';

  @override
  String get coach_recordCalendar_title => '日历';

  @override
  String get coach_recordCalendar_body => '选择日期查看当天的记录。';

  @override
  String get coach_recordAddBtn_title => '添加记录';

  @override
  String get coach_recordAddBtn_body => '点击此按钮添加新的体重记录。';

  @override
  String get coach_chatSuggestion_title => '推荐问题';

  @override
  String get coach_chatSuggestion_body => '点击主题即可向AI提问。';

  @override
  String get coach_chatInput_title => '输入问题';

  @override
  String get coach_chatInput_body => '直接输入问题向AI医生提问。';

  @override
  String get coach_next => '下一步';

  @override
  String get coach_gotIt => '知道了！';

  @override
  String get coach_skip => '跳过';

  @override
  String get weight_selectTime => '测量时间';

  @override
  String get weight_timeNotRecorded => '未记录时间';

  @override
  String get weight_dailyAverage => '日均';

  @override
  String weight_multipleRecords(int count) {
    return '$count次测量';
  }

  @override
  String get weight_addAnother => '再次记录';

  @override
  String get weight_deleteRecord => '确定删除此记录？';

  @override
  String get weight_deleteConfirm => '删除';

  @override
  String get weight_amPeriod => '上午';

  @override
  String get weight_pmPeriod => '下午';

  @override
  String get diet_serving => '投喂';

  @override
  String get diet_eating => '进食';

  @override
  String get diet_addServing => '添加投喂记录';

  @override
  String get diet_addEating => '添加进食记录';

  @override
  String get diet_addRecord => '添加记录';

  @override
  String get diet_totalServed => '总投喂量';

  @override
  String get diet_totalEaten => '总进食量';

  @override
  String get diet_eatingRate => '进食率';

  @override
  String diet_eatingRateValue(int rate) {
    return '$rate%';
  }

  @override
  String get diet_selectTime => '投喂/进食时间';

  @override
  String diet_servingSummary(int count, String grams) {
    return '投喂 $count次 · ${grams}g';
  }

  @override
  String diet_eatingSummary(int count, String grams) {
    return '进食 $count次 · ${grams}g';
  }

  @override
  String get diet_selectType => '记录类型';

  @override
  String get diet_foodName => '食物名称';

  @override
  String get diet_amount => '量(g)';

  @override
  String get diet_memo => '备注（选填）';
}
