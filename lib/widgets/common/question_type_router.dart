import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/question.dart';
import '../question_types/single_choice_widget.dart';
import '../question_types/multiple_response_widget.dart';
import '../question_types/matching_widget.dart';
import '../question_types/pulldown_widget.dart';
import '../question_types/case_scenario_widget.dart';

/// Sceglie il widget giusto in base a [Question.type]. Un solo punto
/// nel codice sa "quale widget serve per quale tipo" — le schermate
/// che mostrano domande (question_screen.dart) non devono saperlo.
class QuestionTypeRouter extends StatelessWidget {
  final Question question;
  final bool showFeedback;
  final ValueChanged<dynamic> onAnswered;

  const QuestionTypeRouter({
    super.key,
    required this.question,
    required this.onAnswered,
    this.showFeedback = false,
  });

  @override
  Widget build(BuildContext context) {
    switch (question.type) {
      case AppConstants.typeMultipleResponse:
        return MultipleResponseWidget(
          question: question,
          showFeedback: showFeedback,
          onAnswered: onAnswered,
        );
      case AppConstants.typeMatching:
        return MatchingWidget(
          question: question,
          showFeedback: showFeedback,
          onAnswered: onAnswered,
        );
      case AppConstants.typePulldown:
        return PulldownWidget(
          question: question,
          showFeedback: showFeedback,
          onAnswered: onAnswered,
        );
      case AppConstants.typeCaseScenario:
        return CaseScenarioWidget(
          question: question,
          showFeedback: showFeedback,
          onAnswered: onAnswered,
        );
      case AppConstants.typeHotspot:
      case AppConstants.typeGraphic:
        // Point & Click e Graphic-Based: implementazione minimale,
        // trattate come scelta singola su etichette testuali finché
        // non aggiungiamo un CustomPainter dedicato per gli hotspot.
        return SingleChoiceWidget(
          question: question,
          showFeedback: showFeedback,
          onAnswered: onAnswered,
        );
      case AppConstants.typeSingleChoice:
      default:
        return SingleChoiceWidget(
          question: question,
          showFeedback: showFeedback,
          onAnswered: onAnswered,
        );
    }
  }
}
