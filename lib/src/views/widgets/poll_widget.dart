import 'package:flutter/material.dart';

class PollWidget extends StatelessWidget {
  const PollWidget({
    super.key,
    required this.question,
    required this.options,
    required this.votes,
    required this.currentUserId,
    required this.onVote,
    this.isLocal = false,
  });

  final String question;
  final List<String> options;
  final Map<String, List<String>> votes;
  final String currentUserId;
  final ValueChanged<int> onVote;
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    int totalVotes = 0;
    for (final list in votes.values) {
      totalVotes += list.length;
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.poll_rounded,
                size: 16,
                color: isLocal ? colors.onPrimaryContainer : colors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isLocal ? colors.onPrimaryContainer : colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(options.length, (index) {
            final opt = options[index];
            final optVotes = votes[index.toString()] ?? [];
            final count = optVotes.length;
            final percent = totalVotes > 0 ? (count / totalVotes) : 0.0;
            final isVoted = optVotes.contains(currentUserId);

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => onVote(index),
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    // Percentage Bar
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(alpha: .5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isVoted
                              ? colors.primary
                              : colors.outlineVariant.withValues(alpha: .6),
                          width: isVoted ? 1.6 : 1,
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: percent.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isVoted
                                ? colors.primary.withValues(alpha: .28)
                                : colors.secondaryContainer.withValues(alpha: .35),
                            borderRadius: BorderRadius.circular(9),
                          ),
                        ),
                      ),
                    ),
                    // Content
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Icon(
                              isVoted
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: isVoted
                                  ? colors.primary
                                  : (isLocal
                                      ? colors.onPrimaryContainer
                                          .withValues(alpha: .7)
                                      : colors.onSurfaceVariant),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                opt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      isVoted ? FontWeight.w700 : FontWeight.w500,
                                  color: isLocal
                                      ? colors.onPrimaryContainer
                                      : colors.onSurface,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(percent * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: isLocal
                                    ? colors.onPrimaryContainer
                                        .withValues(alpha: .85)
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 2),
          Text(
            totalVotes == 1 ? '1 voto registrado' : '$totalVotes votos registrados',
            style: TextStyle(
              fontSize: 11,
              color: isLocal
                  ? colors.onPrimaryContainer.withValues(alpha: .7)
                  : colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
