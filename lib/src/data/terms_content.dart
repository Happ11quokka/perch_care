/// 약관 유형
enum TermsType {
  termsOfService,
  privacyPolicy,
}

/// 약관 내용 데이터 (다국어 지원)
class TermsContent {
  TermsContent._();

  static String getContent(TermsType type, {String locale = 'ko'}) {
    switch (type) {
      case TermsType.termsOfService:
        return switch (locale) {
          'zh' => _termsOfServiceZh,
          'en' => _termsOfServiceEn,
          _ => _termsOfServiceKo,
        };
      case TermsType.privacyPolicy:
        return switch (locale) {
          'zh' => _privacyPolicyZh,
          'en' => _privacyPolicyEn,
          _ => _privacyPolicyKo,
        };
    }
  }

  // ─── 한국어 ───

  static const String _termsOfServiceKo = '''
제1조 (목적)
이 약관은 퍼치(이하 "회사")가 제공하는 반려동물 건강 관리 서비스 "퍼치케어"(이하 "서비스")의 이용과 관련하여 회사와 이용자 간의 권리, 의무 및 책임사항, 기타 필요한 사항을 규정함을 목적으로 합니다.

제2조 (정의)
① "서비스"란 회사가 제공하는 반려동물 건강 관리, AI 건강 체크, 체중 추적, 사료·음수 기록 등 관련 제반 서비스를 의미합니다.
② "이용자"란 이 약관에 따라 회사가 제공하는 서비스를 이용하는 회원을 말합니다.
③ "회원"이란 회사에 개인정보를 제공하여 회원등록을 한 자로서, 서비스를 계속적으로 이용할 수 있는 자를 말합니다.

제3조 (약관의 효력 및 변경)
① 이 약관은 서비스를 이용하고자 하는 모든 이용자에 대하여 그 효력을 발생합니다.
② 회사는 관련 법령을 위배하지 않는 범위에서 이 약관을 개정할 수 있으며, 약관이 변경된 경우에는 변경된 약관의 내용과 시행일을 정하여, 그 시행일의 7일 전부터 시행일 전일까지 공지합니다.
③ 이용자가 변경된 약관에 동의하지 않는 경우, 서비스 이용을 중단하고 탈퇴할 수 있습니다.

제4조 (서비스의 제공)
① 회사는 다음과 같은 서비스를 제공합니다.
  1. 반려동물 건강 정보 관리 서비스
  2. AI 기반 건강 체크 서비스
  3. 체중 추적 및 분석 서비스
  4. 사료 및 음수 기록 서비스
  5. 건강 백과사전 서비스
  6. 푸시 알림 서비스 (건강 기록 리마인더 등)
  7. AI 비전 건강체크 서비스 (이미지 기반 건강 분석)
  8. 품종별 표준 체중 정보 서비스
  9. BHI(Bird Health Index) 건강 점수 서비스
  10. AI 대화 기록 저장 서비스
  11. 기타 회사가 추가 개발하거나 제휴를 통해 이용자에게 제공하는 서비스
② 회사는 서비스 개선 및 이용자 편의를 위해 푸시 알림을 발송할 수 있으며, 이용자는 기기 설정을 통해 알림 수신을 거부할 수 있습니다.

제4-2조 (프리미엄 서비스)
① 프리미엄 서비스는 프로모션 코드를 통해 이용할 수 있습니다.
② 프리미엄 전용 기능에는 AI 비전 건강체크 무제한 이용이 포함됩니다.
③ 프리미엄 코드의 유효기간 만료 시, 자동으로 무료 플랜으로 전환됩니다.
④ 프리미엄 만료 후 90일이 경과하면, 서버에 저장된 건강체크 이미지가 자동 삭제됩니다. 건강체크 텍스트 결과는 유지됩니다.
⑤ 이미지 삭제 전 앱 내 알림을 통해 사전 안내합니다.

제5조 (서비스의 중단)
① 회사는 컴퓨터 등 정보통신설비의 보수점검, 교체 및 고장, 통신의 두절 등의 사유가 발생한 경우에는 서비스의 제공을 일시적으로 중단할 수 있습니다.
② 회사는 제1항의 사유로 서비스의 제공이 일시적으로 중단됨으로 인하여 이용자 또는 제3자가 입은 손해에 대하여 배상합니다. 단, 회사에 고의 또는 과실이 없는 경우에는 그러하지 아니합니다.

제6조 (회원가입)
① 이용자는 회사가 정한 가입 양식에 따라 회원정보를 기입한 후 이 약관에 동의한다는 의사표시를 함으로서 회원가입을 신청합니다.
② 회사는 제1항과 같이 회원으로 가입할 것을 신청한 이용자 중 다음 각 호에 해당하지 않는 한 회원으로 등록합니다.

제7조 (회원 탈퇴 및 자격 상실)
① 회원은 회사에 언제든지 탈퇴를 요청할 수 있으며 회사는 즉시 회원탈퇴를 처리합니다.
② 회원이 다음 각 호의 사유에 해당하는 경우, 회사는 회원자격을 제한 및 정지시킬 수 있습니다.
  1. 가입 신청 시에 허위 내용을 등록한 경우
  2. 다른 사람의 서비스 이용을 방해하거나 그 정보를 도용하는 등 전자상거래 질서를 위협하는 경우
  3. 서비스를 이용하여 법령 또는 이 약관이 금지하거나 공서양속에 반하는 행위를 하는 경우

제8조 (이용자의 의무)
① 이용자는 다음 행위를 하여서는 안 됩니다.
  1. 신청 또는 변경 시 허위내용의 등록
  2. 타인의 정보 도용
  3. 회사가 게시한 정보의 변경
  4. 회사가 정한 정보 이외의 정보 등의 송신 또는 게시
  5. 회사 기타 제3자의 저작권 등 지적재산권에 대한 침해
  6. 회사 기타 제3자의 명예를 손상시키거나 업무를 방해하는 행위

제9조 (면책조항)
① 회사는 천재지변 또는 이에 준하는 불가항력으로 인하여 서비스를 제공할 수 없는 경우에는 서비스 제공에 관한 책임이 면제됩니다.
② 회사는 이용자의 귀책사유로 인한 서비스 이용의 장애에 대하여는 책임을 지지 않습니다.
③ AI 건강 체크 및 AI 백과사전 서비스는 참고용 정보를 제공하며, 전문 수의사의 진단을 대체하지 않습니다. 회사는 AI 분석 결과의 정확성에 대해 보증하지 않습니다.
④ 회사는 서비스 품질 향상을 위해 AI 백과사전 및 AI 비전 서비스의 이용 메타데이터(질문 길이, 응답 시간, 분석 모드 등)를 기록할 수 있습니다.
⑤ AI 비전 분석을 위해 업로드된 이미지는 분석 및 기록 보관 목적으로 사용되며, 프리미엄 만료 후 90일 경과 시 자동 삭제됩니다.

제10조 (분쟁 해결)
이 약관에 명시되지 않은 사항은 관계 법령 및 상관례에 따릅니다.

부칙
이 약관은 2026년 3월 7일부터 시행합니다.
''';

  static const String _privacyPolicyKo = '''
퍼치케어 개인정보처리방침

퍼치(이하 "회사")는 이용자의 개인정보를 중요시하며, 「개인정보 보호법」을 준수하고 있습니다.

1. 개인정보의 수집 및 이용 목적
회사는 다음의 목적을 위하여 개인정보를 처리합니다. 처리하고 있는 개인정보는 다음의 목적 이외의 용도로는 이용되지 않으며, 이용 목적이 변경되는 경우에는 별도의 동의를 받는 등 필요한 조치를 이행할 예정입니다.

가. 회원 가입 및 관리
 - 회원 가입의사 확인, 회원제 서비스 제공에 따른 본인 식별·인증, 회원자격 유지·관리, 서비스 부정이용 방지 목적으로 개인정보를 처리합니다.

나. 서비스 제공
 - 반려동물 건강 관리, AI 건강 체크, 체중 추적, 사료·음수 기록 등 서비스 제공 목적으로 개인정보를 처리합니다.

다. 푸시 알림 발송
 - 건강 기록 리마인더, 서비스 공지 등 알림 발송 목적으로 기기 식별자를 처리합니다.

라. 서비스 개선
 - AI 백과사전 및 AI 비전 서비스 품질 향상을 위한 이용 메타데이터(질문 길이, 응답 시간 등) 분석 목적으로 처리합니다.

마. AI 대화 기록 저장
 - AI 백과사전 챗봇 대화 내용을 세션별로 저장하여 서비스를 제공합니다.

바. 고충처리
 - 민원인의 신원 확인, 민원사항 확인, 사실조사를 위한 연락·통지, 처리결과 통보 목적으로 개인정보를 처리합니다.

2. 수집하는 개인정보 항목
가. 필수 항목
 - 이메일 주소, 비밀번호, 닉네임(이름)

나. 선택 항목
 - 프로필 사진, 반려동물 정보(이름, 종, 생년월일, 체중, 사진)

다. 소셜 로그인 시 수집 항목
 - Google: 이메일, 이름, 프로필 사진
 - Apple: 이메일, 이름
 - Kakao: 이메일, 프로필 정보

라. 서비스 이용 과정에서 자동 생성·수집되는 항목
 - 접속 IP, 접속 일시, 서비스 이용 기록, 기기 정보(OS, 기기 모델)
 - 푸시 알림용 기기 식별자(FCM 토큰)
 - AI 백과사전 이용 메타데이터(질문 길이, 응답 시간, 사용 모델 등)
 - AI 비전 분석 메타데이터(분석 모드, 이미지 크기, 분석 시간, 신뢰도 점수)

마. 건강체크 이미지
 - AI 건강 분석을 위해 업로드한 반려동물 사진
 - 프리미엄 만료 후 90일 보관 후 자동 삭제

바. AI 대화 기록
 - 챗봇 대화 내용 (세션별 저장)
 - 회원 탈퇴 시 즉시 삭제

사. 프리미엄 구독 정보
 - 구독 상태, 프리미엄 코드, 만료 일자

아. 기기 로컬 저장 정보
 - 대화 내역 캐시, 건강체크 기록 캐시, 이미지 캐시 (앱 삭제 시 자동 삭제)

3. 개인정보의 보유 및 이용 기간
① 회사는 법령에 따른 개인정보 보유·이용기간 또는 정보주체로부터 개인정보를 수집 시에 동의받은 개인정보 보유·이용기간 내에서 개인정보를 처리·보유합니다.
② 각각의 개인정보 처리 및 보유 기간은 다음과 같습니다.
 - 회원 가입 및 관리: 회원 탈퇴 시까지
 - 서비스 제공: 서비스 공급 완료 및 요금 정산 완료 시까지
 - 건강체크 이미지: 프리미엄 만료 후 90일
 - AI 대화 기록: 회원 탈퇴 시까지
 - 프리미엄 구독 정보: 구독 종료 후 1년
 - 관계 법령에 의한 보존: 해당 법령이 정한 기간

4. 개인정보의 파기
① 회사는 개인정보 보유기간의 경과, 처리목적 달성 등 개인정보가 불필요하게 되었을 때에는 지체 없이 해당 개인정보를 파기합니다.
② 파기의 절차 및 방법은 다음과 같습니다.
 - 전자적 파일: 복구 불가능한 방법으로 영구 삭제
 - 종이 문서: 분쇄기로 분쇄하거나 소각

5. 개인정보의 제3자 제공
회사는 원칙적으로 이용자의 개인정보를 제3자에게 제공하지 않습니다. 다만, 다음의 경우에는 예외로 합니다.
 - 이용자가 사전에 동의한 경우
 - 법령의 규정에 의거하거나, 수사 목적으로 법령에 정해진 절차와 방법에 따라 수사기관의 요구가 있는 경우

6. 외부 서비스 이용
회사는 서비스 제공을 위해 다음 외부 서비스를 이용합니다.
AI 건강 체크 및 백과사전 기능은 회사가 직접 운영하는 AI 서비스로 제공합니다.
 - Firebase Cloud Messaging (Google): 푸시 알림 발송 (기기 식별자가 전송됨)
 - Google Sign-In, Apple Sign In: 소셜 로그인 기능
 - Kakao Login: 소셜 로그인 기능
 - Firebase Analytics (Google): 서비스 사용 통계 분석 (익명화된 이벤트 데이터)

7. 개인정보의 안전성 확보 조치
회사는 개인정보의 안전성 확보를 위해 다음과 같은 조치를 취하고 있습니다.
 - 비밀번호의 암호화: 이용자의 비밀번호는 암호화되어 저장 및 관리됩니다.
 - 해킹 등에 대비한 대책: 침입차단시스템을 이용하여 외부로부터의 무단 접근을 통제하고 있습니다.
 - 접근 통제: 개인정보에 대한 접근 권한을 최소한의 인원으로 제한하고 있습니다.
 - 기기 식별자 관리: FCM 토큰은 로그아웃 또는 회원 탈퇴 시 즉시 삭제됩니다.

8. 이용자의 권리·의무 및 행사방법
① 이용자는 회사에 대해 언제든지 다음 각 호의 개인정보 보호 관련 권리를 행사할 수 있습니다.
 - 개인정보 열람 요구
 - 오류 등이 있을 경우 정정 요구
 - 삭제 요구
 - 처리정지 요구
② 제1항에 따른 권리 행사는 서면, 전자우편 등을 통하여 하실 수 있으며, 회사는 이에 대해 지체 없이 조치하겠습니다.

9. 개인정보 보호책임자
회사는 개인정보 처리에 관한 업무를 총괄해서 책임지고, 개인정보 처리와 관련한 이용자의 불만처리 및 피해구제 등을 위하여 아래와 같이 개인정보 보호책임자를 지정하고 있습니다.

 - 개인정보 보호책임자: 퍼치 개인정보보호팀
 - 연락처: support@perchcare.com

10. 개인정보처리방침 변경
이 개인정보처리방침은 2026년 3월 7일부터 적용됩니다. 변경 사항이 있을 경우, 시행 7일 전부터 앱 내 공지를 통하여 고지할 것입니다.
''';

  // ─── English ───

  static const String _termsOfServiceEn = '''
Article 1 (Purpose)
These Terms of Service govern the rights, obligations, and responsibilities between Perch (hereinafter "the Company") and users regarding the use of the pet health management service "Perch Care" (hereinafter "the Service").

Article 2 (Definitions)
1. "Service" refers to all services provided by the Company, including pet health management, AI health checks, weight tracking, food and water intake recording, and related services.
2. "User" refers to a member who uses the Service in accordance with these Terms.
3. "Member" refers to a person who has registered as a member by providing personal information to the Company and can continuously use the Service.

Article 3 (Effect and Amendment of Terms)
1. These Terms shall be effective for all users who wish to use the Service.
2. The Company may amend these Terms to the extent that they do not violate applicable laws. When Terms are changed, the Company shall announce the amended Terms and the effective date at least 7 days before the effective date.
3. If a user does not agree with the amended Terms, the user may discontinue use of the Service and withdraw membership.

Article 4 (Provision of Service)
1. The Company provides the following services:
  a. Pet health information management
  b. AI-based health check service
  c. Weight tracking and analysis
  d. Food and water intake recording
  e. Health encyclopedia service
  f. Push notification service (health record reminders, etc.)
  g. AI Vision Health Check service (image-based health analysis)
  h. Breed-specific standard weight information service
  i. BHI (Bird Health Index) health scoring service
  j. AI chat history storage service
  k. Other services developed or provided through partnerships
2. The Company may send push notifications for service improvement and user convenience. Users can opt out of notifications through device settings.

Article 4-2 (Premium Service)
1. Premium service can be accessed through promotional codes.
2. Premium-exclusive features include unlimited AI Vision Health Check usage.
3. Upon expiration of the premium code, the account automatically reverts to the free plan.
4. Health check images stored on the server are automatically deleted 90 days after premium expiration. Health check text results are retained.
5. Users will be notified via in-app notification before image deletion.

Article 5 (Service Interruption)
1. The Company may temporarily suspend the Service due to maintenance, replacement, malfunction of IT equipment, or communication disruptions.
2. The Company shall compensate for damages incurred by users or third parties due to temporary service suspension under Paragraph 1, unless the Company is free from intention or negligence.

Article 6 (Membership Registration)
1. Users apply for membership by filling in member information according to the registration form prescribed by the Company and expressing consent to these Terms.
2. The Company shall register applicants as members unless they fall under any disqualifying conditions.

Article 7 (Membership Withdrawal and Disqualification)
1. Members may request withdrawal at any time, and the Company shall process the withdrawal immediately.
2. The Company may restrict or suspend membership if a member:
  a. Registered false information during registration
  b. Interfered with others' use of the Service or misappropriated their information
  c. Engaged in activities prohibited by law or these Terms, or activities against public morals

Article 8 (User Obligations)
1. Users shall not engage in the following activities:
  a. Registering false information during application or modification
  b. Misappropriating others' information
  c. Altering information posted by the Company
  d. Transmitting or posting information other than that designated by the Company
  e. Infringing on intellectual property rights of the Company or third parties
  f. Damaging the reputation of or interfering with the business of the Company or third parties

Article 9 (Disclaimer)
1. The Company shall be exempt from liability for service provision when it cannot provide the Service due to force majeure such as natural disasters.
2. The Company shall not be liable for service interruptions caused by the user's own fault.
3. AI health check and AI encyclopedia services provide reference information only and do not replace professional veterinary diagnosis. The Company does not guarantee the accuracy of AI analysis results.
4. The Company may record usage metadata (question length, response time, analysis mode, etc.) for AI encyclopedia and AI vision service quality improvement.
5. Images uploaded for AI vision analysis are used for analysis and record-keeping purposes and are automatically deleted 90 days after premium expiration.

Article 10 (Dispute Resolution)
Matters not specified in these Terms shall be governed by applicable laws and customs.

Addendum
These Terms shall be effective from March 7, 2026.
''';

  static const String _privacyPolicyEn = '''
Perch Care Privacy Policy

Perch (hereinafter "the Company") values the personal information of its users and complies with the Personal Information Protection Act.

1. Purpose of Collection and Use of Personal Information
The Company processes personal information for the following purposes. Personal information being processed shall not be used for purposes other than the following, and if the purpose of use changes, necessary measures such as obtaining separate consent will be implemented.

a. Member Registration and Management
 - Personal information is processed for the purpose of confirming membership intent, identity verification for member service provision, membership maintenance and management, and prevention of unauthorized use.

b. Service Provision
 - Personal information is processed for the purpose of providing services such as pet health management, AI health checks, weight tracking, and food/water intake recording.

c. Push Notification Delivery
 - Device identifiers are processed for the purpose of sending health record reminders, service announcements, and other notifications.

d. Service Improvement
 - Usage metadata (question length, response time, etc.) is processed for the purpose of improving AI encyclopedia and AI vision service quality.

e. AI Chat History Storage
 - AI encyclopedia chatbot conversation content is stored per session for service provision.

f. Complaint Handling
 - Personal information is processed for the purpose of verifying the identity of complainants, confirming complaints, contacting for fact-finding, and notifying results.

2. Personal Information Collected
a. Required Items
 - Email address, password, nickname (name)

b. Optional Items
 - Profile photo, pet information (name, species, date of birth, weight, photo)

c. Items Collected During Social Login
 - Google: Email, name, profile photo
 - Apple: Email, name
 - Kakao: Email, profile information

d. Items Automatically Generated/Collected During Service Use
 - Access IP, access time, service usage records, device information (OS, device model)
 - Device identifier for push notifications (FCM token)
 - AI encyclopedia usage metadata (question length, response time, model used, etc.)
 - AI vision analysis metadata (analysis mode, image size, analysis time, confidence score)

e. Health Check Images
 - Pet photos uploaded for AI health analysis
 - Automatically deleted 90 days after premium expiration

f. AI Chat History
 - Chatbot conversation content (stored per session)
 - Immediately deleted upon account withdrawal

g. Premium Subscription Information
 - Subscription status, premium code, expiration date

h. Device Local Storage Information
 - Chat history cache, health check record cache, image cache (automatically deleted when app is uninstalled)

3. Retention and Use Period of Personal Information
1) The Company processes and retains personal information within the retention and use period prescribed by law or agreed upon at the time of collection.
2) The retention periods are as follows:
 - Member registration and management: Until membership withdrawal
 - Service provision: Until service provision and payment settlement are completed
 - Health check images: 90 days after premium expiration
 - AI chat history: Until membership withdrawal
 - Premium subscription information: 1 year after subscription ends
 - Retention under applicable laws: For the period prescribed by the relevant law

4. Destruction of Personal Information
1) The Company shall destroy personal information without delay when it becomes unnecessary due to expiration of the retention period or achievement of the processing purpose.
2) Destruction procedures and methods:
 - Electronic files: Permanently deleted using irrecoverable methods
 - Paper documents: Shredded or incinerated

5. Provision of Personal Information to Third Parties
The Company does not, in principle, provide users' personal information to third parties. However, exceptions are made in the following cases:
 - When the user has given prior consent
 - When required by law or by investigative agencies following legally prescribed procedures

6. Use of External Services
The Company uses the following external services for service provision:
AI health check and encyclopedia features are provided through the Company's in-house AI service.
 - Firebase Cloud Messaging (Google): Push notification delivery (device identifiers are transmitted)
 - Google Sign-In, Apple Sign In: Social login features
 - Kakao Login: Social login feature
 - Firebase Analytics (Google): Service usage statistics analysis (anonymized event data)

7. Measures for Security of Personal Information
The Company takes the following measures to ensure the security of personal information:
 - Password encryption: User passwords are encrypted for storage and management
 - Countermeasures against hacking: Intrusion prevention systems are used to control unauthorized external access
 - Access control: Access to personal information is limited to the minimum number of personnel
 - Device identifier management: FCM tokens are immediately deleted upon logout or membership withdrawal

8. Rights and Obligations of Users
1) Users may exercise the following personal information protection rights at any time:
 - Request to view personal information
 - Request for correction of errors
 - Request for deletion
 - Request to stop processing
2) Rights under Paragraph 1 may be exercised through written documents or email, and the Company shall take action without delay.

9. Personal Information Protection Officer
The Company designates a Personal Information Protection Officer as follows to oversee personal information processing and handle user complaints and damage relief:

 - Personal Information Protection Officer: Perch Privacy Team
 - Contact: support@perchcare.com

10. Changes to Privacy Policy
This Privacy Policy shall be effective from March 7, 2026. Any changes will be announced through in-app notifications at least 7 days before implementation.
''';

  // ─── 中文 ───

  static const String _termsOfServiceZh = '''
第一条（目的）
本条款旨在规定Perch（以下简称"公司"）提供的宠物健康管理服务"Perch Care"（以下简称"服务"）的使用相关事项，包括公司与用户之间的权利、义务及责任事项等。

第二条（定义）
① "服务"是指公司提供的宠物健康管理、AI健康检查、体重追踪、饲料及饮水记录等相关所有服务。
② "用户"是指根据本条款使用公司提供的服务的会员。
③ "会员"是指向公司提供个人信息并完成注册，可持续使用服务的人。

第三条（条款的效力及变更）
① 本条款对所有希望使用服务的用户生效。
② 公司可在不违反相关法律法规的范围内修订本条款。条款变更时，公司将在生效日前7天公告变更内容和生效日期。
③ 用户不同意变更后的条款时，可停止使用服务并注销账户。

第四条（服务的提供）
① 公司提供以下服务：
  1. 宠物健康信息管理服务
  2. 基于AI的健康检查服务
  3. 体重追踪及分析服务
  4. 饲料及饮水记录服务
  5. 健康百科服务
  6. 推送通知服务（健康记录提醒等）
  7. AI视觉健康检查服务（基于图像的健康分析）
  8. 品种标准体重信息服务
  9. BHI（Bird Health Index）健康评分服务
  10. AI对话记录存储服务
  11. 公司另行开发或通过合作向用户提供的其他服务
② 公司可为改善服务和方便用户发送推送通知，用户可通过设备设置拒绝接收通知。

第四-二条（高级版服务）
① 高级版服务可通过促销代码使用。
② 高级版专属功能包括AI视觉健康检查无限使用。
③ 高级版代码有效期届满后，自动转为免费方案。
④ 高级版到期90天后，服务器上存储的健康检查图片将自动删除。健康检查文字结果将予以保留。
⑤ 图片删除前，将通过应用内通知提前告知。

第五条（服务的中断）
① 因信息通信设备的维修、更换、故障或通信中断等原因，公司可暂时中断服务。
② 因第一项原因导致服务暂时中断，给用户或第三方造成损害的，公司应予以赔偿。但公司无故意或过失的情况除外。

第六条（会员注册）
① 用户按照公司规定的注册格式填写信息，并表示同意本条款，即可申请注册。
② 公司对申请注册的用户，除符合以下各项情形外，均予以注册。

第七条（会员退出及资格丧失）
① 会员可随时向公司申请退出，公司将立即处理。
② 会员存在以下情形时，公司可限制或暂停其会员资格：
  1. 注册时登记虚假信息的
  2. 妨碍他人使用服务或盗用他人信息等威胁电子商务秩序的
  3. 利用服务从事法律法规或本条款禁止的行为，或违反公序良俗的

第八条（用户的义务）
① 用户不得从事以下行为：
  1. 申请或变更时登记虚假信息
  2. 盗用他人信息
  3. 篡改公司发布的信息
  4. 发送或发布公司规定以外的信息
  5. 侵犯公司及第三方的著作权等知识产权
  6. 损害公司及第三方的名誉或妨碍其业务

第九条（免责条款）
① 因不可抗力（如自然灾害等）导致无法提供服务时，公司免除服务提供责任。
② 因用户自身原因导致的服务使用障碍，公司不承担责任。
③ AI健康检查及AI百科服务仅提供参考信息，不能替代专业兽医诊断。公司不保证AI分析结果的准确性。
④ 公司可记录AI百科及AI视觉服务的使用元数据（提问长度、响应时间、分析模式等）以提升服务质量。
⑤ 为AI视觉分析上传的图片用于分析及记录保管目的，高级版到期90天后自动删除。

第十条（争议解决）
本条款未规定的事项，按照相关法律法规及商业惯例处理。

附则
本条款自2026年3月7日起施行。
''';

  static const String _privacyPolicyZh = '''
Perch Care 隐私政策

Perch（以下简称"公司"）重视用户的个人信息，并遵守《个人信息保护法》。

1. 个人信息的收集及使用目的
公司为以下目的处理个人信息。所处理的个人信息不会用于以下目的以外的用途，如使用目的发生变更，将另行征得同意等采取必要措施。

一、会员注册及管理
 - 为确认注册意向、提供会员服务所需的身份识别与认证、维护会员资格、防止服务滥用等目的处理个人信息。

二、服务提供
 - 为提供宠物健康管理、AI健康检查、体重追踪、饲料及饮水记录等服务处理个人信息。

三、推送通知发送
 - 为发送健康记录提醒、服务公告等通知处理设备标识符。

四、服务改善
 - 为提升AI百科及AI视觉服务质量，分析使用元数据（提问长度、响应时间等）。

五、AI对话记录存储
 - AI百科聊天机器人对话内容按会话存储，用于服务提供。

六、投诉处理
 - 为确认投诉人身份、确认投诉事项、联系调查、通知处理结果等目的处理个人信息。

2. 收集的个人信息项目
一、必选项目
 - 电子邮箱、密码、昵称（姓名）

二、可选项目
 - 头像照片、宠物信息（名称、品种、出生日期、体重、照片）

三、社交登录时收集的项目
 - Google：电子邮箱、姓名、头像照片
 - Apple：电子邮箱、姓名
 - Kakao：电子邮箱、个人资料信息

四、服务使用过程中自动生成/收集的项目
 - 访问IP、访问时间、服务使用记录、设备信息（操作系统、设备型号）
 - 推送通知用设备标识符（FCM令牌）
 - AI百科使用元数据（提问长度、响应时间、使用模型等）
 - AI视觉分析元数据（分析模式、图片大小、分析时间、置信度分数）

五、健康检查图片
 - 为AI健康分析上传的宠物照片
 - 高级版到期90天后自动删除

六、AI对话记录
 - 聊天机器人对话内容（按会话存储）
 - 注销会员时立即删除

七、高级版订阅信息
 - 订阅状态、高级版代码、到期日期

八、设备本地存储信息
 - 对话记录缓存、健康检查记录缓存、图片缓存（卸载应用时自动删除）

3. 个人信息的保留及使用期限
① 公司在法律规定的保留期限内或收集时征得同意的保留期限内处理和保留个人信息。
② 各项个人信息的处理和保留期限如下：
 - 会员注册及管理：至会员注销时
 - 服务提供：至服务提供及费用结算完成时
 - 健康检查图片：高级版到期后90天
 - AI对话记录：至会员注销时
 - 高级版订阅信息：订阅结束后1年
 - 依据相关法律保留：相关法律规定的期限

4. 个人信息的销毁
① 个人信息保留期限届满或处理目的达成后，公司将立即销毁相关个人信息。
② 销毁的程序和方法如下：
 - 电子文件：以不可恢复的方式永久删除
 - 纸质文件：用碎纸机粉碎或焚烧

5. 向第三方提供个人信息
公司原则上不向第三方提供用户的个人信息。但以下情况除外：
 - 用户事先同意的
 - 依据法律规定或侦查机关按照法定程序和方法提出要求的

6. 外部服务使用
公司为提供服务使用以下外部服务：
AI健康检查及百科功能由公司自研并直接运营的AI服务提供。
 - Firebase Cloud Messaging (Google)：发送推送通知（设备标识符将被传输）
 - Google Sign-In, Apple Sign In：社交登录功能
 - Kakao Login：社交登录功能
 - Firebase Analytics (Google)：服务使用统计分析（匿名化事件数据）

7. 个人信息安全保障措施
公司采取以下措施确保个人信息安全：
 - 密码加密：用户密码经加密后存储和管理
 - 防黑客对策：使用入侵防御系统控制外部未授权访问
 - 访问控制：将个人信息的访问权限限制在最少人员范围内
 - 设备标识符管理：FCM令牌在注销或退出会员时立即删除

8. 用户的权利、义务及行使方法
① 用户可随时向公司行使以下个人信息保护相关权利：
 - 要求查阅个人信息
 - 要求更正错误
 - 要求删除
 - 要求停止处理
② 第一项权利可通过书面或电子邮件方式行使，公司将立即采取措施。

9. 个人信息保护负责人
公司指定以下个人信息保护负责人，全面负责个人信息处理相关工作，处理用户投诉及损害救济：

 - 个人信息保护负责人：Perch 隐私保护团队
 - 联系方式：support@perchcare.com

10. 隐私政策变更
本隐私政策自2026年3月7日起适用。如有变更，将在实施前7天通过应用内公告通知。
''';
}
