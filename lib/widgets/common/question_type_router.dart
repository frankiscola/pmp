import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/question.dart';
import '../question_types/single_choice_widget.dart';
import '../question_types/multiple_response_widget.dart';
import '../question_types/matching_widget.dart';
import '../question_types/pulldown_widget.dart';
import '../question_types/case_scenario_widget.dart';
import '../question_types/point_and_click_widget.dart';

/// Sceglie il widget giusto in base a [Question.type]. Un solo punto
/// nel codice sa "quale widget serve per quale tipo" — le schermate
/// che mostrano domande (question_screen.dart) non devono saperlo.
class QuestionTypeRouter extends StatelessWidget {
  final Question question;
  final bool revealed;
  final ValueChanged<dynamic> onAnswered;

  const QuestionTypeRouter({
    super.key,
    required this.question,
    required this.onAnswered,
    this.revealed = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case AppConstants.typeMultipleResponse:
        return MultipleResponseWidget(
          question: question,
          revealed: revealed,
          onAnswered: onAnswered,
        );
      case AppConstants.typeMatching:
        return MatchingWidget(
          question: question,
          revealed: revealed,
          onAnswered: onAnswered,
        );
      case AppConstants.typePulldown:
        return PulldownWidget(
          question: question,
          revealed: revealed,
          onAnswered: onAnswered,
        );
      case AppConstants.typeCaseScenario:
        return CaseScenarioWidget(
          question: question,
          revealed: revealed,
          onAnswered: onAnswered,
        );
      case AppConstants.typeHotspot:
        return PointAndClickWidget(
          question: question,
          revealed: revealed,
          onAnswered: onAnswered,
        );
      case AppConstants.typeGraphic:
        // Graphic-Based: per ora usa Single Choice testuale, dato che le
        // domande di questo tipo (es. lettura di un network diagram) sono
        // già strutturate con "options" id/text, non con hotspot cliccabili.
        return SingleChoiceWidget(
          question: question,
          revealed: revealed,
          onAnswered: onAnswered,
        );
      case AppConstants.typeSingleChoice:
      default:
        return SingleChoiceWidget(
          question: question,
          revealed: revealed,
          onAnswered: onAnswered,
        );
    }
  }
}
