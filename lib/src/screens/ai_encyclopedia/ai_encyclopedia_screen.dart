import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../config/app_config.dart';
import '../../models/chat_message.dart';
import '../../models/pet.dart';
import '../../router/route_names.dart';
import '../../services/analytics/analytics_service.dart';
import '../../services/chat/chat_api_service.dart';
import '../../services/ai/ai_encyclopedia_service.dart';
import '../../services/ai/ai_stream_service.dart';
import '../../services/storage/chat_storage_service.dart';
import '../../services/storage/local_image_storage_service.dart';
import '../../theme/colors.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/app_loading.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../widgets/local_image_avatar.dart';
import '../../widgets/quota_badge.dart';
import '../../services/coach_mark/coach_mark_service.dart';
import '../../theme/durations.dart';
import '../../services/premium/premium_service.dart';
import '../../providers/premium_provider.dart';
import '../../services/api/api_client.dart';
import '../../services/api/token_service.dart';
import '../../providers/pet_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AIEncyclopediaScreen extends ConsumerStatefulWidget {
  const AIEncyclopediaScreen({super.key});

  @override
  ConsumerState<AIEncyclopediaScreen> createState() =>
      _AIEncyclopediaScreenState();
}

class _AIEncyclopediaScreenState extends ConsumerState<AIEncyclopediaScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final AiEncyclopediaService _aiService = AiEncyclopediaService.instance;
  final AiStreamService _streamService = AiStreamService.instance;
  final ChatStorageService _chatStorage = ChatStorageService.instance;
  final ChatApiService _chatApi = ChatApiService.instance;
  final List<ChatMessage> _messages = [];
  Pet? _activePet;
  String? _currentSessionId;
  StreamSubscription<String>? _streamSubscription;
  int? _assistantPlaceholderIndex; // 스트리밍 중 assistant 메시지 인덱스 고정
  int _receivedTokenCount = 0; // P1: fallback 판단용 수신 토큰 수
  Timer? _throttleTimer; // P2: setState 쓰로틀링

  // Coach mark target keys
  final _suggestionKey = GlobalKey();
  final _inputKey = GlobalKey();
  bool _isSending = false;
  bool _isTyping = false;
  bool _isLoadingMessages = true;
  bool _showPremiumBanner = false;
  PremiumStatus? _premiumStatus;
  bool _isQuotaExhausted = false;

  // 둥둥 떠다니는 breathing 애니메이션
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  // 타이핑 시 살짝 커지는 반응 애니메이션
  late final AnimationController _peekController;
  late final Animation<double> _peekScale;

  bool get _hasUserMessages => _messages.any((m) => m.role == MessageRole.user);

  @override
  void initState() {
    super.initState();
    _initializeChat();

    // 부드럽게 위아래로 떠다니는 애니메이션 (무한 반복)
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // 타자 칠 때 살짝 커지는 애니메이션
    _peekController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _peekScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _peekController, curve: Curves.easeOutBack),
    );

    _inputController.addListener(_onInputChanged);
  }

  /// 채팅 초기화: 펫 로드 후 해당 펫의 대화 내역 로드
  Future<void> _initializeChat() async {
    await _loadActivePet();
    await _loadMessages();
    _maybeShowCoachMarks();
    _loadPremiumBannerState();
    _loadQuota(logView: true);
  }

  /// Phase 2: 쿼터 정보 로드 (forceRefresh로 최신 데이터 조회)
  /// [logView] true일 때만 ai_quota_viewed analytics 이벤트를 발화 (화면 진입 시만).
  Future<void> _loadQuota({bool logView = false}) async {
    try {
      final status =
          await ref.read(premiumStatusProvider.notifier).refreshAndGet();
      if (mounted) {
        setState(() {
          _premiumStatus = status;
          _isQuotaExhausted =
              status.quota?.aiEncyclopedia.isExhausted ?? false;
        });
        // 쿼터 조회 analytics (화면 진입 시에만)
        if (logView) {
          final quota = status.quota;
          if (quota != null && !quota.aiEncyclopedia.isUnlimited) {
            AnalyticsService.instance.logQuotaViewed(
              remaining: quota.aiEncyclopedia.remaining,
              tier: status.tier,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[AIEncyclopedia] Failed to load quota: $e');
    }
  }

  String get _bannerDismissKey {
    final userId = TokenService.instance.userId ?? 'anonymous';
    return 'encyclopedia_banner_dismissed_$userId';
  }

  Future<void> _loadPremiumBannerState() async {
    // App Store 3.1.1 대응: 프리미엄 게이팅 비활성화 시 배너 노출 안 함
    if (!AppConfig.premiumEnabled) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool(_bannerDismissKey) ?? false;
      if (dismissed) return;

      final status = await ref.read(premiumStatusProvider.future);
      if (mounted && status.isFree) {
        setState(() {
          _showPremiumBanner = true;
        });
      }
    } catch (_) {
      // 실패 시 배너 미표시
    }
  }

  Future<void> _dismissPremiumBanner() async {
    setState(() {
      _showPremiumBanner = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_bannerDismissKey, true);
    } catch (_) {}
  }

  Future<void> _maybeShowCoachMarks() async {
    // Welcome 상태(대화 없음)에서만 표시
    if (_messages.isNotEmpty) return;
    final service = CoachMarkService.instance;
    if (await service.hasSeen(CoachMarkService.screenChatbot)) return;
    if (!mounted) return;
    await Future.delayed(AppDurations.coachMarkDelay);
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    final steps = [
      CoachMarkStep(
        targetKey: _suggestionKey,
        title: l10n.coach_chatSuggestion_title,
        body: l10n.coach_chatSuggestion_body,
        isScrollable: false,
      ),
      CoachMarkStep(
        targetKey: _inputKey,
        title: l10n.coach_chatInput_title,
        body: l10n.coach_chatInput_body,
        isScrollable: false,
      ),
    ];
    CoachMarkOverlay.show(
      context,
      steps: steps,
      nextLabel: l10n.coach_next,
      gotItLabel: l10n.coach_gotIt,
      skipLabel: l10n.coach_skip,
      onComplete: () => service.markSeen(CoachMarkService.screenChatbot),
    );
  }

  void _onInputChanged() {
    final typing = _inputController.text.trim().isNotEmpty;
    if (typing == _isTyping) return;
    _isTyping = typing;
    if (typing) {
      _peekController.forward();
    } else {
      _peekController.reverse();
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _throttleTimer?.cancel();
    _inputController.removeListener(_onInputChanged);
    _floatController.dispose();
    _peekController.dispose();
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _handleSend() async {
    if (_isSending) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    // Phase 2: 쿼터 소진 시 전송 차단
    if (_isQuotaExhausted) {
      AppSnackBar.error(
        context,
        message: AppLocalizations.of(context).aiEncyclopedia_quotaExhausted,
      );
      return;
    }

    AnalyticsService.instance.logAiChatSent();

    final history = _buildCleanHistory();
    final petId = _activePet?.id;
    final petProfileContext = _buildPetProfileContext();

    setState(() {
      _isSending = true;
      _receivedTokenCount = 0;
      _messages.add(
        ChatMessage(
          role: MessageRole.user,
          text: text,
          timestamp: DateTime.now(),
        ),
      );
      // 스트리밍 시작: 빈 placeholder로 시작
      _messages.add(
        ChatMessage(
          role: MessageRole.assistant,
          text: '',
          timestamp: DateTime.now(),
        ),
      );
      // P1: placeholder 인덱스 고정 (race condition 방지)
      _assistantPlaceholderIndex = _messages.length - 1;
    });

    setState(() {
      _inputController.clear();
    });

    _scrollToBottom();

    // 서버 세션 생성 또는 메시지 저장
    if (_currentSessionId == null) {
      try {
        final session = await _chatApi.createSession(
          petId: petId,
          firstMessage: text,
        );
        _currentSessionId = session.id;
      } catch (e) {
        debugPrint('[AIEncyclopedia] Session creation failed: $e');
      }
    } else {
      try {
        await _chatApi.addMessage(
          sessionId: _currentSessionId!,
          role: 'user',
          content: text,
        );
      } catch (e) {
        debugPrint('[AIEncyclopedia] User message save failed: $e');
      }
    }

    try {
      // SSE 스트리밍 시도
      await _handleStreamResponse(
        query: text,
        history: history,
        petId: petId,
        petProfileContext: petProfileContext,
      );
    } catch (e) {
      if (!mounted) return;
      // Phase 2: 429 quota exceeded → quota 새로고침 + 에러 표시
      if (e is ApiException && e.statusCode == 429) {
        debugPrint('[AIEncyclopedia] Quota exceeded (429)');
        AnalyticsService.instance.logQuotaReached(
          feature: 'ai_encyclopedia',
          usedCount: _premiumStatus?.quota?.aiEncyclopedia.monthlyUsed ?? 0,
        );
        _loadQuota();
        setState(() {
          _updateAssistantMessage(
            text: AppLocalizations.of(context).aiEncyclopedia_quotaExhausted,
            timestamp: DateTime.now(),
          );
          _isSending = false;
        });
        _assistantPlaceholderIndex = null;
        return;
      }
      // P1: 토큰을 하나도 못 받았을 때만 동기 API fallback
      if (_receivedTokenCount == 0) {
        debugPrint('[AIEncyclopedia] SSE failed (0 tokens), falling back: $e');
        await _handleFallbackResponse(
          query: text,
          history: history,
          petId: petId,
          petProfileContext: petProfileContext,
        );
      } else {
        // 일부 토큰 수신 후 실패 → 연결 끊김 처리
        debugPrint(
          '[AIEncyclopedia] SSE interrupted after $_receivedTokenCount tokens: $e',
        );
        _finishStreaming();
      }
    }
  }

  /// P1: assistant placeholder 인덱스가 유효한지 확인하고 메시지를 업데이트.
  void _updateAssistantMessage({String? text, DateTime? timestamp}) {
    final idx = _assistantPlaceholderIndex;
    if (idx == null || idx >= _messages.length) return;
    final msg = _messages[idx];
    if (msg.role != MessageRole.assistant) return;
    _messages[idx] = msg.copyWith(
      text: text ?? msg.text,
      timestamp: timestamp ?? msg.timestamp,
    );
  }

  /// 스트리밍 종료 공통 처리.
  void _finishStreaming() {
    _throttleTimer?.cancel();
    _throttleTimer = null;
    if (mounted) {
      setState(() {
        _isSending = false;
      });
      _saveMessages();
      _saveAssistantMessageToServer(); // placeholder 인덱스 초기화 전에 호출
      _scrollToBottom();
      _loadQuota(); // Phase 2: 전송 완료 후 quota 배지 갱신
    }
    _assistantPlaceholderIndex = null;
  }

  /// assistant 메시지를 서버에 저장 (fire-and-forget)
  Future<void> _saveAssistantMessageToServer() async {
    if (_currentSessionId == null) return;
    final idx = _assistantPlaceholderIndex;
    if (idx == null || idx >= _messages.length) return;
    final msg = _messages[idx];
    if (msg.role != MessageRole.assistant || msg.text.isEmpty) return;
    try {
      await _chatApi.addMessage(
        sessionId: _currentSessionId!,
        role: 'assistant',
        content: msg.text,
      );
    } catch (e) {
      debugPrint('[AIEncyclopedia] Assistant message save failed: $e');
    }
  }

  /// SSE 스트리밍으로 토큰별 실시간 응답을 처리한다.
  Future<void> _handleStreamResponse({
    required String query,
    required List<Map<String, String>> history,
    String? petId,
    String? petProfileContext,
  }) async {
    final completer = Completer<void>();
    // P2: 토큰 버퍼 (쓰로틀링용)
    final tokenBuffer = StringBuffer();

    _streamSubscription = _streamService
        .streamEncyclopedia(
          query: query,
          history: history,
          petId: petId,
          petProfileContext: petProfileContext,
        )
        .listen(
          (token) {
            if (!mounted) return;
            _receivedTokenCount++;
            tokenBuffer.write(token);

            // P2: 50ms 쓰로틀링 — 버퍼에 모아서 일괄 반영
            _throttleTimer ??= Timer(const Duration(milliseconds: 50), () {
              _throttleTimer = null;
              if (!mounted) return;
              final buffered = tokenBuffer.toString();
              tokenBuffer.clear();
              if (buffered.isEmpty) return;

              setState(() {
                final idx = _assistantPlaceholderIndex;
                if (idx != null && idx < _messages.length) {
                  final msg = _messages[idx];
                  _messages[idx] = msg.copyWith(text: msg.text + buffered);
                }
              });
              _scrollToBottom();
            });
          },
          onDone: () {
            // 남은 버퍼 플러시
            final remaining = tokenBuffer.toString();
            tokenBuffer.clear();
            if (remaining.isNotEmpty && mounted) {
              setState(() {
                final idx = _assistantPlaceholderIndex;
                if (idx != null && idx < _messages.length) {
                  final msg = _messages[idx];
                  _messages[idx] = msg.copyWith(text: msg.text + remaining);
                }
              });
            }
            _finishStreaming();
            _streamSubscription = null;
            if (!completer.isCompleted) completer.complete();
          },
          onError: (error) {
            // 남은 버퍼 플러시
            final remaining = tokenBuffer.toString();
            tokenBuffer.clear();
            if (remaining.isNotEmpty && mounted) {
              setState(() {
                final idx = _assistantPlaceholderIndex;
                if (idx != null && idx < _messages.length) {
                  final msg = _messages[idx];
                  _messages[idx] = msg.copyWith(text: msg.text + remaining);
                }
              });
            }
            _streamSubscription = null;
            if (!completer.isCompleted) completer.completeError(error);
          },
          cancelOnError: true,
        );

    return completer.future;
  }

  /// SSE 실패 시 기존 동기 API로 fallback.
  Future<void> _handleFallbackResponse({
    required String query,
    required List<Map<String, String>> history,
    String? petId,
    String? petProfileContext,
  }) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);

    // placeholder를 "준비 중..."으로 변경
    setState(() {
      _updateAssistantMessage(text: l10n.chatbot_preparingAnswer);
    });

    try {
      final answer = await _aiService.ask(
        query: query,
        history: history,
        petId: petId,
        petProfileContext: petProfileContext,
      );

      if (!mounted) return;
      setState(() {
        _updateAssistantMessage(text: answer, timestamp: DateTime.now());
      });
      await _saveMessages();
      await _saveAssistantMessageToServer();
    } catch (e) {
      if (!mounted) return;
      final l10nErr = AppLocalizations.of(context);
      // Phase 2: 429 quota exceeded → quota 새로고침 + 에러 표시
      if (e is ApiException && e.statusCode == 429) {
        debugPrint('[AIEncyclopedia] Fallback quota exceeded (429)');
        AnalyticsService.instance.logQuotaReached(
          feature: 'ai_encyclopedia',
          usedCount: _premiumStatus?.quota?.aiEncyclopedia.monthlyUsed ?? 0,
        );
        _loadQuota();
        setState(() {
          _updateAssistantMessage(
            text: l10nErr.aiEncyclopedia_quotaExhausted,
            timestamp: DateTime.now(),
          );
        });
        return;
      }
      setState(() {
        _updateAssistantMessage(
          text: l10nErr.chatbot_aiError,
          timestamp: DateTime.now(),
        );
      });
      debugPrint('[AIEncyclopedia] Fallback API error: $e');
      AppSnackBar.error(
        context,
        message: l10nErr.chatbot_aiCallFailed(e.toString()),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
      _assistantPlaceholderIndex = null;
      _scrollToBottom();
    }
  }

  Future<void> _loadActivePet() async {
    try {
      final pet = ref.read(activePetProvider).valueOrNull;
      if (!mounted) return;
      setState(() {
        _activePet = pet;
      });
    } catch (_) {
      // ignore load failures and allow AI to work without personalization
    }
  }

  /// 저장된 대화 내역 로드 (서버 우선, 로컬 폴백)
  Future<void> _loadMessages() async {
    setState(() {
      _isLoadingMessages = true;
    });

    try {
      // 서버에서 세션 목록 로드 시도
      final sessions = await _chatApi.getUserSessions();
      final petId = _activePet?.id;
      final matching = sessions.where((s) => s.petId == petId).toList();
      if (matching.isNotEmpty) {
        final session = matching.first;
        _currentSessionId = session.id;
        final serverMessages = await _chatApi.getSessionMessages(session.id);
        if (!mounted) return;
        setState(() {
          _messages.clear();
          _messages.addAll(serverMessages);
          _isLoadingMessages = false;
        });
        // 로컬 캐시 업데이트
        await _chatStorage.saveMessages(petId, _messages);
        _scrollToBottom();
        return;
      }
    } catch (e) {
      debugPrint('[AIEncyclopedia] Server load failed, using local: $e');
    }

    // 로컬 폴백
    try {
      final messages = await _chatStorage.loadMessages(_activePet?.id);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
        _isLoadingMessages = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMessages = false;
        });
      }
    }
  }

  /// 대화 내역 저장
  Future<void> _saveMessages() async {
    await _chatStorage.saveMessages(_activePet?.id, _messages);
  }

  /// 대화 내역 삭제 (P1: 스트리밍 중에는 비활성화)
  Future<void> _clearMessages() async {
    if (_isSending) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chatbot_clearHistory),
        content: Text(l10n.chatbot_clearHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.common_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _chatStorage.clearMessages(_activePet?.id);
      // 서버 세션 삭제
      if (_currentSessionId != null) {
        try {
          await _chatApi.deleteSession(_currentSessionId!);
        } catch (e) {
          debugPrint('[AIEncyclopedia] Session delete failed: $e');
        }
        _currentSessionId = null;
      }
      if (mounted) {
        setState(() {
          _messages.clear();
        });
        AppSnackBar.success(context, message: l10n.chatbot_historyCleared);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.nearBlack,
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.goNamed(RouteNames.home);
            }
          },
        ),
        centerTitle: true,
        title: Text(l10n.chatbot_title),
        titleTextStyle: AppTypography.h6.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.nearBlack,
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.nearBlack),
            onSelected: (value) {
              if (value == 'clear') {
                _clearMessages();
              }
            },
            itemBuilder: (menuContext) => [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, size: 20),
                    const SizedBox(width: 8),
                    Text(l10n.chatbot_clearHistory),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: _premiumStatus?.quota != null &&
                !_premiumStatus!.quota!.aiEncyclopedia.isUnlimited
            ? PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: QuotaBadge(
                    quota: _premiumStatus!.quota!.aiEncyclopedia,
                    normalText: l10n.quotaBadge_normal(
                      _premiumStatus!.quota!.aiEncyclopedia.remaining,
                    ),
                    exhaustedText: l10n.quotaBadge_exhausted,
                  ),
                ),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoadingMessages
                  ? AppLoading.fullPage()
                  : _hasUserMessages
                  ? _buildMessages()
                  : _buildWelcomeView(),
            ),
            if (!_hasUserMessages && !_isLoadingMessages)
              _buildSuggestionChips(),
            if (_showPremiumBanner) _buildPremiumBanner(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // ── Welcome view (initial state) ──────────────────────────────────

  Widget _buildWelcomeView() {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAvatarWithGlow(size: 160),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              l10n.chatbot_welcomeTitle,
              style: AppTypography.h2.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.nearBlack,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.chatbot_welcomeDescription,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.gray500,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Avatar with blur glow (Flutter-rendered) ──────────────────────

  Widget _buildAvatarWithGlow({required double size}) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatAnimation, _peekScale]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _floatAnimation.value),
          child: Transform.scale(scale: _peekScale.value, child: child),
        );
      },
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 블러 글로우 배경
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                width: size * 0.55,
                height: size * 0.55,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.gradientBottomAlt,
                      AppColors.brandPrimary,
                      AppColors.yellow,
                    ],
                  ),
                ),
              ),
            ),
            // 앵무새 아이콘
            SvgPicture.asset(
              'assets/images/chatbot_icon.svg',
              width: size * 0.55,
              height: size * 0.55,
            ),
          ],
        ),
      ),
    );
  }

  // ── Small bot avatar for message bubbles ───────────────────────────

  Widget _buildSmallBotAvatar() {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.gradientBottomAlt,
                    AppColors.brandPrimary,
                    AppColors.yellow,
                  ],
                ),
              ),
            ),
          ),
          SvgPicture.asset(
            'assets/images/chatbot_icon.svg',
            width: 22,
            height: 22,
          ),
        ],
      ),
    );
  }

  // ── Small user avatar for message bubbles ──────────────────────────

  Widget _buildSmallUserAvatar() {
    final pet = _activePet;
    if (pet != null) {
      return LocalImageAvatar(
        ownerType: ImageOwnerType.petProfile,
        ownerId: pet.id,
        size: 36,
        placeholder: ClipOval(
          child: SvgPicture.asset(
            'assets/images/profile/pet_profile_placeholder.svg',
            width: 36,
            height: 36,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.gray350,
      ),
      child: const Icon(Icons.person, size: 20, color: Colors.white),
    );
  }

  // ── Suggestion chips ──────────────────────────────────────────────

  Widget _buildSuggestionChips() {
    final l10n = AppLocalizations.of(context);
    final samples = [
      l10n.chatbot_suggestion1,
      l10n.chatbot_suggestion2,
      l10n.chatbot_suggestion3,
      l10n.chatbot_suggestion4,
    ];

    return Container(
      key: _suggestionKey,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: samples
            .map(
              (q) => Semantics(
                button: true,
                label: q,
                child: GestureDetector(
                onTap: () {
                  _inputController.text = q;
                  _handleSend();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    q,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.nearBlack,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── Messages list ─────────────────────────────────────────────────

  Widget _buildMessages() {
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isUser = message.role == MessageRole.user;
        return _buildMessageBubble(message, isUser);
      },
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemCount: _messages.length,
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isUser) {
    if (isUser) {
      // 사용자 메시지: 오른쪽 정렬 + 프로필 사진
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.lg),
                  topRight: Radius.circular(AppRadius.lg),
                  bottomLeft: Radius.circular(AppRadius.lg),
                  bottomRight: Radius.circular(AppRadius.xs),
                ),
              ),
              child: Text(
                message.text,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.nearBlack,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _buildSmallUserAvatar(),
        ],
      );
    }

    // Assistant 메시지: 왼쪽 정렬 + 봇 아바타
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSmallBotAvatar(),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: const BoxDecoration(
              color: AppColors.gray100,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.xs),
                topRight: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(AppRadius.lg),
                bottomRight: Radius.circular(AppRadius.lg),
              ),
            ),
            child: message.text.isEmpty && _isSending
                ? _buildTypingIndicator()
                : MarkdownBody(
                    data: message.text,
                    styleSheet: MarkdownStyleSheet(
                      p: AppTypography.bodyMedium.copyWith(
                        color: AppColors.nearBlack,
                      ),
                      strong: AppTypography.bodyMedium.copyWith(
                        color: AppColors.nearBlack,
                        fontWeight: FontWeight.w700,
                      ),
                      listBullet: AppTypography.bodyMedium.copyWith(
                        color: AppColors.nearBlack,
                      ),
                    ),
                    selectable: true,
                    shrinkWrap: true,
                  ),
          ),
        ),
      ],
    );
  }

  // ── Typing indicator (3 dots animation) ──────────────────────────

  Widget _buildTypingIndicator() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, _) {
        // _floatController cycles 0→1→0 over 2400ms.
        // Use its value to stagger 3 dots with phase offsets.
        final t = _floatController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot peaks at a different phase (0.0, 0.33, 0.66)
            final phase = (t + i * 0.33) % 1.0;
            final opacity =
                0.3 + 0.7 * (phase < 0.5 ? phase * 2 : (1.0 - phase) * 2);
            return Padding(
              padding: EdgeInsets.only(right: i < 2 ? 4.0 : 0.0),
              child: Opacity(
                opacity: opacity.clamp(0.3, 1.0),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.gray400,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ── Input area ────────────────────────────────────────────────────

  Widget _buildPremiumBanner() {
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome,
            color: AppColors.brandPrimary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.chatbot_premiumBanner,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.nearBlack,
                    height: 1.4,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  button: true,
                  label: l10n.chatbot_premiumUpgrade,
                  child: GestureDetector(
                  onTap: () async {
                    AnalyticsService.instance.logPremiumFeatureBlocked(
                      feature: 'ai',
                      sourceScreen: 'ai_encyclopedia',
                    );
                    await context.push(
                      '/home/premium?source=ai_banner&feature=ai',
                    );
                    if (!mounted) return;
                    try {
                      final status = await ref.read(premiumStatusProvider.notifier).refreshAndGet();
                      if (!mounted || status.isFree) return;
                      setState(() {
                        _showPremiumBanner = false;
                      });
                    } catch (_) {}
                  },
                  child: Text(
                    l10n.chatbot_premiumUpgrade,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Close',
            child: GestureDetector(
            onTap: _dismissPremiumBanner,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 18, color: AppColors.warmGray),
            ),
          ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final l10n = AppLocalizations.of(context);

    return Container(
      key: _inputKey,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.gray100,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: TextField(
                controller: _inputController,
                enabled: !_isQuotaExhausted,
                onTapOutside: (event) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: _isQuotaExhausted
                      ? l10n.aiEncyclopedia_quotaExhaustedHint
                      : l10n.chatbot_inputHint,
                ),
                style: AppTypography.bodyMedium,
                minLines: 1,
                maxLines: 3,
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Semantics(
            button: true,
            label: 'Send message',
            child: GestureDetector(
            onTap: _isSending ? null : _handleSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.brandPrimary,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  String? _buildPetProfileContext() {
    final pet = _activePet;
    if (pet == null) return null;

    final l10n = AppLocalizations.of(context);

    final details = <String>['- ${l10n.ai_petInfoPrefix}: ${pet.name}'];

    final breed = pet.breed?.trim();
    if (breed != null && breed.isNotEmpty) {
      details.add('- ${l10n.ai_breedPrefix}: $breed');
    }

    if (pet.birthDate != null) {
      details.add(
        '- ${l10n.ai_agePrefix}: ${_formatAge(pet.birthDate!)} (${l10n.ai_birthdayPrefix} ${pet.birthDate!.toIso8601String().split('T').first})',
      );
    }

    final gender = _mapGender(pet.gender);
    if (gender != null) {
      details.add('- $gender');
    }

    if (details.isEmpty) return null;

    return [
      l10n.ai_petContextInstruction,
      ...details,
      l10n.ai_petContextAdvice,
    ].join('\n');
  }

  String? _mapGender(String? gender) {
    final l10n = AppLocalizations.of(context);
    switch (gender) {
      case 'male':
        return l10n.ai_genderMale;
      case 'female':
        return l10n.ai_genderFemale;
      case 'unknown':
        return l10n.ai_genderUnknown;
      default:
        return null;
    }
  }

  String _formatAge(DateTime birthDate) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;
    int days = now.day - birthDate.day;

    if (days < 0) {
      months -= 1;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }

    final segments = <String>[];
    if (years > 0) segments.add(l10n.ai_ageYears(years));
    if (months > 0) segments.add(l10n.ai_ageMonths(months));
    if (segments.isEmpty) segments.add(l10n.ai_ageLessThanMonth);

    return segments.join(' ');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// user/assistant가 번갈아 나와야 하므로 히스토리를 정리한다.
  List<Map<String, String>> _buildCleanHistory() {
    final filtered = <ChatMessage>[];

    for (final m in _messages) {
      if (filtered.isEmpty && m.role == MessageRole.assistant) {
        continue;
      }
      if (filtered.isNotEmpty && filtered.last.role == m.role) {
        filtered[filtered.length - 1] = m;
        continue;
      }
      filtered.add(m);
    }

    const maxMessages = 10;
    final truncated = filtered.length > maxMessages
        ? filtered.sublist(filtered.length - maxMessages)
        : filtered;

    return truncated
        .map(
          (m) => {
            'role': m.role == MessageRole.user ? 'user' : 'assistant',
            'content': m.text,
          },
        )
        .toList();
  }
}
