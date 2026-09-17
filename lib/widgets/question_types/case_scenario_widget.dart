import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../models/question.dart';
import 'single_choice_widget.dart';
import 'multiple_response_widget.dart';

/// Case/Scenario Question — un testo di contesto (spesso lungo) seguito
/// da una o più domande collegate. Lo scenario resta visibile e
/// "sticky" mentre lo studente scorre le sotto-domande, così non deve
/// ricordarselo a memoria — esattamente come nel vero CBT PMI.
class CaseScenarioWidget extends StatefulWidget {
  final Question question;
  final bool revealed;
  final ValueChanged<Map<String, dynamic>> onAnswered;

  const CaseScenarioWidget({
    super.key,
    required this.question,
    required this.onAnswered,
    this.revealed = false,
  });

  @override
  State<CaseScenarioWidget> createState() => _CaseScenarioWidgetState();
}

class _CaseScenarioWidgetState extends State<CaseScenarioWidget> {
  final Map<String, dynamic> _subAnswers = {};
  bool _scenarioExpanded = true;

  @override
  Widget build(BuildContext context) {
    final scenarioText = widget.question.options['scenario'] as String? ?? '';
    final subQuestions = List<Map<String, dynamic>>.from(
      widget.question.options['subQuestions'] as List? ?? [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () =>
                    setState(() => _scenarioExpanded = !_scenarioExpanded),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.article_outlined,
                        size: 20,
                        color: AppColors.pmiBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Scenario',
                          style: AppTextStyles.titleMedium,
                        ),
                      ),
                      Icon(
                        _scenarioExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
              if (_scenarioExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Text(scenarioText, style: AppTextStyles.bodyLarge),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (int i = 0; i < subQuestions.length; i++) ...[
          Text(
            'Domanda ${i + 1} di ${subQuestions.length}',
            style: AppTextStyles.label,
          ),
          const SizedBox(height: 8),
          Text(
            subQuestions[i]['question_text'] as String,
            style: AppTextStyles.question,
          ),
          const SizedBox(height: 12),
          _buildSubQuestion(subQuestions[i], i),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildSubQuestion(Map<String, dynamic> subQ, int index) {
    final type = subQ['type'] as String? ?? 'single_choice';
    final subQuestion = _questionFromMap(subQ);

    if (type == 'multiple_response') {
      return MultipleResponseWidget(
        question: subQuestion,
        revealed: widget.revealed,
        onAnswered: (answer) {
          _subAnswers['sub_$index'] = answer;
          widget.onAnswered(_subAnswers);
        },
      );
    }
    return SingleChoiceWidget(
      question: subQuestion,
      revealed: widget.revealed,
      onAnswered: (answer) {
        _subAnswers['sub_$index'] = answer;
        widget.onAnswered(_subAnswers);
      },
    );
  }

  Question _questionFromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] as String? ?? '',
      domain: widget.question.domain,
      type: map['type'] as String? ?? 'single_choice',
      questionText: map['question_text'] as String? ?? '',
      options: {'options': map['options']},
      correctAnswers: map['correct_answers'],
      explanation: map['explanation'] as String? ?? '',
      source: widget.question.source,
      topic: widget.question.topic,
    );
  }
}
