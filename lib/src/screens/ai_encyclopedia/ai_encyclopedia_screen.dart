import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/colors.dart';
import '../../theme/radius.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../services/ai/ai_encyclopedia_service.dart';

class AIEncyclopediaScreen extends StatefulWidget {
  const AIEncyclopediaScreen({super.key});

  @override
  State<AIEncyclopediaScreen> createState() => _AIEncyclopediaScreenState();
}

class _AIEncyclopediaScreenState extends State<AIEncyclopediaScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final AiEncyclopediaService _aiService = AiEncyclopediaService();
  final List<_Message> _messages = [
    _Message(
      role: MessageRole.assistant,
      text: '앵무새 케어에 대해 무엇이든 물어보세요.\n'
          '예: "모이 섞을 때 비율이 어떻게 돼?"',
      timestamp: DateTime.now(),
    ),
  ];
  bool _isSending = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  void _handleSend() async {
    if (_isSending) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    final history = _buildCleanHistory();

    setState(() {
      _isSending = true;
      _messages.add(
        _Message(
          role: MessageRole.user,
          text: text,
          timestamp: DateTime.now(),
        ),
      );
      _messages.add(
        _Message(
          role: MessageRole.assistant,
          text: '답변을 준비하고 있어요...',
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
      );

      setState(() {
        _messages[_messages.length - 1] = _messages.last.copyWith(
          text: answer,
          timestamp: DateTime.now(),
        );
      });
    } catch (e) {
      setState(() {
        _messages[_messages.length - 1] = _messages.last.copyWith(
          text: 'AI 응답에 실패했어요. 잠시 후 다시 시도해 주세요.',
          timestamp: DateTime.now(),
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 호출 실패: $e')),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: AppColors.nearBlack,
          onPressed: () => context.pop(),
        ),
        title: const Text('AI 백과사전'),
        titleTextStyle: AppTypography.h6.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.nearBlack,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeroCard(),
            _buildRecommendedQuestions(),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: _buildMessages()),
            _buildInputArea(),
          ],
        ),
      ),
    );
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

  /// Perplexity는 user/assistant가 번갈아 나와야 하므로 히스토리를 정리한다.
  List<Map<String, String>> _buildCleanHistory() {
    final filtered = <_Message>[];

    for (final m in _messages) {
      // 맨 앞의 assistant-only 메시지는 건너뛴다.
      if (filtered.isEmpty && m.role == MessageRole.assistant) {
        continue;
      }
      // 같은 role이 연속되면 마지막만 유지한다.
      if (filtered.isNotEmpty && filtered.last.role == m.role) {
        filtered[filtered.length - 1] = m;
        continue;
      }
      filtered.add(m);
    }

    // 최근 10개(5쌍)만 사용해 토큰을 절약
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

  Widget _buildHeroCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.gradientTop, AppColors.gradientBottom],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '앵무새 AI 백과',
                  style: AppTypography.h5.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '사료, 체중, 환경 관리까지 궁금한 걸 질문해 주세요.',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Text('🦜', style: TextStyle(fontSize: 34)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedQuestions() {
    const samples = [
      '초기 비타민 섭취량',
      '털 갈이 때 돌봄 방법',
      '건강검진 주기 추천',
      '체중 기록 팁',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '추천 질문',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.nearBlack,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
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
                        horizontal: AppSpacing.md,
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
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.md,
        ),
        itemBuilder: (context, index) {
          final message = _messages[index];
          final isUser = message.role == MessageRole.user;
          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: isUser
                      ? AppColors.brandPrimary
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppRadius.lg),
                    topRight: const Radius.circular(AppRadius.lg),
                    bottomLeft: Radius.circular(
                      isUser ? AppRadius.lg : AppRadius.sm,
                    ),
                    bottomRight: Radius.circular(
                      isUser ? AppRadius.sm : AppRadius.lg,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: AppTypography.bodySmall.copyWith(
                    color: isUser ? Colors.white : AppColors.nearBlack,
                  ),
                ),
              ),
            ),
          );
        },
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.md),
        itemCount: _messages.length,
      ),
    );
  }

  Widget _buildInputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.gray100,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: TextField(
                  controller: _inputController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '궁금한 점을 입력하세요',
                  ),
                  minLines: 1,
                  maxLines: 3,
                  onSubmitted: (_) => _handleSend(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              height: 48,
              width: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandPrimary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                onPressed: _isSending ? null : _handleSend,
                child: _isSending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum MessageRole { user, assistant }

class _Message {
  _Message({
    required this.role,
    required this.text,
    required this.timestamp,
  });

  final MessageRole role;
  final String text;
  final DateTime timestamp;

  _Message copyWith({
    MessageRole? role,
    String? text,
    DateTime? timestamp,
  }) {
    return _Message(
      role: role ?? this.role,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
