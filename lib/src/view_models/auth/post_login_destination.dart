/// 로그인 성공 직후 이동할 목적지.
enum PostLoginDestination { home, onboarding }

/// hasPets tri-state(true/false/null) → 라우팅 목적지.
///
/// - false : 확실히 펫이 없음 → 온보딩(펫 등록)으로 보낸다.
/// - true  : 펫이 있음 → 홈.
/// - null  : 조회 실패(불확실) → 온보딩으로 잘못 보내 등록 화면에 갇히지 않도록
///           안전하게 홈으로 보낸다.
PostLoginDestination destinationForHasPets(bool? hasPets) =>
    hasPets == false ? PostLoginDestination.onboarding : PostLoginDestination.home;
