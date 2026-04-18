/// 저장 결과를 View에 전달하기 위한 공용 enum.
///
/// 서버 저장 성공 = `online`, 네트워크 실패 등으로 오프라인 큐에 적재 = `offline`.
/// View는 이 값에 따라 다른 스낵바(saved vs savedOffline)를 표시한다.
enum SaveOutcome { online, offline }
