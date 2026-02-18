import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../models/chat_message.dart';
import '../../models/pet.dart';
import '../../router/route_names.dart';
import '../../services/ai/ai_encyclopedia_service.dart';
import '../../services/api/token_service.dart';
import '../../services/pet/pet_service.dart';
import '../../services/storage/chat_storage_service.dart';
import '../../services/storage/local_image_storage_service.dart';
import '../../theme/colors.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/coach_mark_overlay.dart';
import '../../widgets/local_image_avatar.dart';
import '../../services/coach_mark/coach_mark_service.dart';

class AIEncyclopediaScreen extends StatefulWidget {
  const AIEncyclopediaScreen({super.key});

  @override
  State<AIEncyclopediaScreen> createState() => _AIEncyclopediaScreenState();
}

class _AIEncyclopediaScreenState extends State<AIEncyclopediaScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final AiEncyclopediaService _aiService = AiEncyclopediaService();
  final PetService _petService = PetService.instance;
  final ChatStorageService _chatStorage = ChatStorageService.instance;
  final List<ChatMessage> _messages = [];
  Pet? _activePet;

  // Coach mark target keys
  final _suggestionKey = GlobalKey();
  final _inputKey = GlobalKey();
  bool _isSending = false;
  bool _isTyping = false;
  bool _isLoadingMessages = true;

  // 둥둥 떠다니는 breathing 애니메이션
  late final AnimationController _floatController;
  late final Animation<double> _floatAnimation;

  // 타이핑 시 살짝 커지는 반응 애니메이션
  late final AnimationController _peekController;
  late final Animation<double> _peekScale;

  bool get _hasUserMessages =>
      _messages.any((m) => m.role == MessageRole.user);

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
  }

  Future<void> _maybeShowCoachMarks() async {
    // Welcome 상태(대화 없음)에서만 표시
    if (_messages.isNotEmpty) return;
    final service = CoachMarkService.instance;
    if (await service.hasSeenChatbotCoachMarks()) return;
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 800));
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
      onComplete: () => service.markChatbotCoachMarksSeen(),
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

    final l10n = AppLocalizations.of(context);
    final history = _buildCleanHistory();

    setState(() {
      _isSending = true;
      _messages.add(
        ChatMessage(
          role: MessageRole.user,
          text: text,
          timestamp: DateTime.now(),
        ),
      );
      _messages.add(
        ChatMessage(
          role: MessageRole.assistant,
          text: l10n.chatbot_preparingAnswer,
          timestamp: DateTime.now(),
        ),
      );
    });

    setState(() {
      _inputController.clear();
    });

    _scrollToBottom();

    try {
      final answer = await _aiService.ask(
        query: text,
        history: history,
        petId: _activePet?.id,
        petProfileContext: _buildPetProfileContext(),
      );

      setState(() {
        _messages[_messages.length - 1] = _messages.last.copyWith(
          text: answer,
          timestamp: DateTime.now(),
        );
      });

      // AI 응답 성공 시 대화 저장
      await _saveMessages();
    } catch (e) {
      if (mounted) {
        final l10nErr = AppLocalizations.of(context);
        setState(() {
          _messages[_messages.length - 1] = _messages.last.copyWith(
            text: l10nErr.chatbot_aiError,
            timestamp: DateTime.now(),
          );
        });
        AppSnackBar.error(context, message: l10nErr.chatbot_aiCallFailed(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
      _scrollToBottom();
    }
  }

  Future<void> _loadActivePet() async {
    try {
      final pet = await _petService.getActivePet();
      if (!mounted) return;
      setState(() {
        _activePet = pet;
      });
    } catch (_) {
      // ignore load failures and allow AI to work without personalization
    }
  }

  /// 저장된 대화 내역 로드
  Future<void> _loadMessages() async {
    setState(() {
      _isLoadingMessages = true;
    });

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

  /// 대화 내역 삭제
  Future<void> _clearMessages() async {
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
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: Text(l10n.common_delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _chatStorage.clearMessages(_activePet?.id);
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
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.nearBlack,
            ),
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoadingMessages
                  ? const Center(child: CircularProgressIndicator())
                  : _hasUserMessages
                      ? _buildMessages()
                      : _buildWelcomeView(),
            ),
            if (!_hasUserMessages && !_isLoadingMessages) _buildSuggestionChips(),
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
          child: Transform.scale(
            scale: _peekScale.value,
            child: child,
          ),
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
                      Color(0xFFFF5C2F),
                      AppColors.brandPrimary,
                      Color(0xFFFFE812),
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
                    Color(0xFFFF5C2F),
                    AppColors.brandPrimary,
                    Color(0xFFFFE812),
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
    final userId = TokenService.instance.userId;
    if (userId != null) {
      return LocalImageAvatar(
        ownerType: ImageOwnerType.userProfile,
        ownerId: userId,
        size: 36,
        placeholder: SvgPicture.asset(
          'assets/images/profile/profile.svg',
          width: 36,
          height: 36,
        ),
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFD9D9D9),
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
              (q) => GestureDetector(
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
            child: Text(
              message.text,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.nearBlack,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Input area ────────────────────────────────────────────────────

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
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
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
                onTapOutside: (event) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: l10n.chatbot_inputHint,
                ),
                style: AppTypography.bodyMedium,
                minLines: 1,
                maxLines: 3,
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          GestureDetector(
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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 22,
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

    final details = <String>[
      '- 이름: ${pet.name}',
    ];

    final breed = pet.breed?.trim();
    if (breed != null && breed.isNotEmpty) {
      details.add('- 품종: $breed');
    }

    if (pet.birthDate != null) {
      details.add('- 나이: ${_formatAge(pet.birthDate!)} (생일 ${pet.birthDate!.toIso8601String().split('T').first})');
    }

    final gender = _mapGender(pet.gender);
    if (gender != null) {
      details.add('- 성별: $gender');
    }

    if (details.isEmpty) return null;

    return [
      '사용자가 다중 프로필에서 선택한 앵무새 정보를 참고해.',
      ...details,
      '가능한 한 위 앵무새 조건(특히 품종)을 기준으로 맞춤 조언을 제공해.',
    ].join('\n');
  }

  String? _mapGender(String? gender) {
    switch (gender) {
      case 'male':
        return '수컷';
      case 'female':
        return '암컷';
      case 'unknown':
        return '성별 미상';
      default:
        return null;
    }
  }

  String _formatAge(DateTime birthDate) {
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
    if (years > 0) segments.add('$years세');
    if (months > 0) segments.add('$months개월');
    if (segments.isEmpty) segments.add('1개월 미만');

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
