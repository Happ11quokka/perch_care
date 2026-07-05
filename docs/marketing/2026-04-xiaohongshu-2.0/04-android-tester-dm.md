# 안드로이드 내부 테스터 DM 스크립트

Google Play **Internal Testing 트랙**을 통한 비공개 베타 배포용 스크립트입니다.

---

## 사전 준비 (발행 전 완료 필수)

- [ ] Google Play Console → Internal Testing 트랙 생성
- [ ] 테스터 명단 관리 방법 결정
  - **옵션 A:** Google 그룹(권장) — 이메일 한 곳에 관리
  - **옵션 B:** Play Console에 이메일 직접 입력 (소수 시)
  - **옵션 C:** 구글 폼으로 사전 수집 → 배치 업로드
- [ ] 테스트 빌드 v2.0.1 (or later) 업로드 완료
- [ ] 내부 테스터 초대 링크 확보

---

## 🇨🇳 중국어 DM (메인)

**상황 1: 댓글에서 지원한 유저에게 먼저 DM 개시**

```
您好！🦜
谢谢您对陪伴鹦鹉 2.0 的关注！
看到您在评论留言想做安卓内测用户，超开心～

如果方便的话，
请把您的 Google 账号邮箱
（就是您 Google Play 登录用的那个）发给我们。

我们会把您添加到 Google Play 的内测名单里，
之后您就能在 Play Store 直接下载测试版 ✨

说明几点：
1. 内测版可能会有一些小 bug，发现问题随时告诉我们～
2. 您的邮箱只用于加入内测，不会用作其他用途
3. 内测期间所有 AI 功能都免费开放
4. 您的反馈会直接影响正式版的样子 💪

期待和您一起把安卓版做得更好！❤️
```

**상황 2: 이메일 수령 후 확인 메시지**

```
收到您的邮箱啦！感谢 🙏
我们会在 24 小时内把您加进内测名单，
加好之后您会收到 Google Play 的邀请邮件。

拿到邀请邮件后：
1. 点击邮件里的"接受邀请"链接
2. 跳转到 Play Store 页面安装 app
3. 第一次打开可能需要 1-2 分钟同步数据

开始使用如果遇到任何问题，
或者有想到的功能建议，
随时私信我们就好～🦜
```

**상황 3: 테스터 명단 풀 시 안내**

```
您好 🙏
非常抱歉，这次内测名额已经满了……
但是您的邮箱我们已经登记，
下一批开放的时候会优先通知您！

如果您愿意，
也可以先在 iPhone/iPad 上试试（如果方便），
提前给我们反馈意见，
这样安卓正式版上架时就能更完善。

真的很感谢您的耐心和支持 ❤️
```

---

## 🇬🇧 영어 DM (해외 사용자 대응)

**메인:**
```
Hi there! 🦜
Thanks so much for your interest in beta-testing
Perch Care 2.0 on Android!

Could you share your Google account email
(the one you use for Google Play)?

We'll add you to our Internal Test track,
and you'll be able to install the beta
directly from Play Store ✨

A few notes:
1. The beta may have minor bugs — please let us know!
2. We'll only use your email for the test track.
3. All AI features are free during the beta.
4. Your feedback shapes the public release 💪

Looking forward to building Android together! ❤️
```

**접수 확인:**
```
Got your email — thank you! 🙏
We'll add you to the test list within 24 hours,
and you'll receive an invite from Google Play soon.

Once the invite arrives:
1. Click "Accept Invitation" in the email
2. You'll be redirected to Play Store to install
3. First launch may take 1-2 minutes to sync

Any issues or feature ideas — just DM us! 🦜
```

**명단 마감:**
```
Hi! 🙏
Unfortunately the current beta cohort is full.
But we've saved your email,
and we'll reach out first when the next batch opens.

If you have access to an iPhone/iPad,
feel free to try the iOS version in the meantime —
early feedback there helps the Android launch too.

Truly appreciate your patience ❤️
```

---

## 📋 DM 관리 체크리스트

발행 후 DM 처리 시 각 유저별로:

- [ ] 댓글/DM 유입 경로 기록 (어느 포스트 댓글인지)
- [ ] 언어 (중국어/영어) 구분 후 템플릿 선택
- [ ] 이메일 수령 → 24시간 내 Play Console 추가
- [ ] 추가 완료 후 "상황 2" 확인 메시지 발송
- [ ] 반응/피드백 주간 단위로 집계

---

## 🔒 개인정보 주의

- 이메일은 **내부 테스팅 트랙 추가 목적으로만** 사용
- 외부 시트/DB에 저장 시 접근 권한 최소화
- 유저가 탈퇴/삭제 요청 시 즉시 명단에서 제거
- **개인정보 처리방침 (중국어판)** 에 이 사용 목적이 명시돼 있는지 확인:
  - `docs/privacy-policy-zh.html`
  - 누락 시 "베타 테스터 관리" 항목 추가 후 발행

---

## 📊 성공 지표 (Reference)

- **목표 베타 테스터 수:** 30~50명 (Google Play Internal Testing 트랙 상한 100명 고려)
- **유지율:** 1주일 후 설치 유지 70%+
- **피드백 제공률:** 테스터의 30%+ 가 최소 1건 이상 피드백 제공
- **중대 버그:** 발견된 Crash/블로커 48시간 내 핫픽스

이 지표는 안드로이드 정식 출시 시점 판단에 사용.
