import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/chart/base/base_chart/base_chart_painter.dart';
import 'package:fl_chart/src/chart/base/line.dart';
import 'package:fl_chart/src/extensions/paint_extension.dart';
import 'package:fl_chart/src/utils/canvas_wrapper.dart';
import 'package:fl_chart/src/utils/utils.dart';
import 'package:flutter/material.dart';

import 'pie_chart_data.dart';

/// Paints [PieChartData] in the canvas, it can be used in a [CustomPainter]
class PieChartPainter extends BaseChartPainter<PieChartData> {
  late Paint _sectionPaint, _sectionStrokePaint, _centerSpacePaint;

  /// Paints [dataList] into canvas, it is the animating [PieChartData],
  /// [targetData] is the animation's target and remains the same
  /// during animation, then we should use it  when we need to show
  /// tooltips or something like that, because [dataList] is changing constantly.
  ///
  /// [textScale] used for scaling texts inside the chart,
  /// parent can use [MediaQuery.textScaleFactor] to respect
  /// the system's font size.
  PieChartPainter() : super() {
    _sectionPaint = Paint()..style = PaintingStyle.stroke;

    _sectionStrokePaint = Paint()..style = PaintingStyle.stroke;

    _centerSpacePaint = Paint()..style = PaintingStyle.fill;
  }

  /// Paints [PieChartData] into the provided canvas.
  @override
  void paint(BuildContext context, CanvasWrapper canvasWrapper,
      PaintHolder<PieChartData> holder) {
    super.paint(context, canvasWrapper, holder);
    final data = holder.data;
    if (data.sections.isEmpty) {
      return;
    }

    final sectionsAngle = calculateSectionsAngle(data.sections, data.sumValue);
    final centerRadius = calculateCenterRadius(canvasWrapper.size, holder);

    drawCenterSpace(canvasWrapper, centerRadius, holder);
    drawSections(canvasWrapper, sectionsAngle, centerRadius, holder);
    drawTexts(context, canvasWrapper, holder, centerRadius);
  }

  @visibleForTesting
  List<double> calculateSectionsAngle(
      List<PieChartSectionData> sections, double sumValue) {
    return sections.map((section) {
      return 360 * (section.value / sumValue);
    }).toList();
  }

  @visibleForTesting
  void drawCenterSpace(CanvasWrapper canvasWrapper, double centerRadius,
      PaintHolder<PieChartData> holder) {
    final data = holder.data;
    final viewSize = canvasWrapper.size;
    final centerX = viewSize.width / 2;
    final centerY = viewSize.height / 2;

    _centerSpacePaint.color = data.centerSpaceColor;
    canvasWrapper.drawCircle(
        Offset(centerX, centerY), centerRadius, _centerSpacePaint);
  }

  @visibleForTesting
  void drawSections(
    CanvasWrapper canvasWrapper,
    List<double> sectionsAngle,
    double centerRadius,
    PaintHolder<PieChartData> holder,
  ) {
    final data = holder.data;
    final viewSize = canvasWrapper.size;

    final center = Offset(viewSize.width / 2, viewSize.height / 2);

    var tempAngle = data.startDegreeOffset;

    for (var i = 0; i < data.sections.length; i++) {
      final section = data.sections[i];
      final sectionDegree = sectionsAngle[i];

      if (sectionDegree == 360) {
        final radius = centerRadius + section.radius / 2;
        final rect = Rect.fromCircle(center: center, radius: radius);
        _sectionPaint.setColorOrGradient(
            section.color,
            section.gradient,
            rect,
        );
        _sectionPaint.strokeWidth = section.radius;
        _sectionPaint.style = PaintingStyle.stroke;
        canvasWrapper.drawCircle(
          center,
          centerRadius + section.radius / 2,
          _sectionPaint,
        );
        if (section.borderSide.width != 0.0 &&
            section.borderSide.color.opacity != 0.0) {
          _sectionStrokePaint.strokeWidth = section.borderSide.width;
          _sectionStrokePaint.color = section.borderSide.color;
          canvasWrapper.drawCircle(
            center,
            centerRadius + section.radius - (section.borderSide.width / 2),
            _sectionStrokePaint,
          );
        }
        return;
      }

      var sectionPath = generateSectionPath(
        section,
        data.sectionsSpace,
        tempAngle,
        sectionDegree,
        data.roundedCornerDegrees,
        data.roundedCornerRadius,
        center,
        centerRadius,
      );

      drawSection(section, sectionPath, canvasWrapper);
      drawSectionStroke(section, sectionPath, canvasWrapper, viewSize);
      tempAngle += sectionDegree;
    }
  }

  /// Generates a path around a section
  @visibleForTesting
  Path generateSectionPath(
    PieChartSectionData section,
    double sectionSpace,
    double tempAngle,
    double sectionDegree,
    double roundedCornerDegrees,
    double roundedCornerRadius,
    Offset center,
    double centerRadius,
  ) {
    final sectionRadiusRect = Rect.fromCircle(
      center: center,
      radius: centerRadius + section.radius,
    );

    final centerRadiusRect = Rect.fromCircle(
      center: center,
      radius: centerRadius,
    );

    final startRadians = Utils().radians(tempAngle);
    final sweepRadians = Utils().radians(sectionDegree);
    final endRadians = startRadians + sweepRadians;

    final startLineDirection =
        Offset(math.cos(startRadians), math.sin(startRadians));

    final startLineFrom = center + startLineDirection * centerRadius;
    final startLineTo = startLineFrom + startLineDirection * section.radius;
    final startLine = Line(startLineFrom, startLineTo);

    final endLineDirection = Offset(math.cos(endRadians), math.sin(endRadians));

    final endLineFrom = center + endLineDirection * centerRadius;
    final endLineTo = endLineFrom + endLineDirection * section.radius;
    final endLine = Line(endLineFrom, endLineTo);

    var sectionPath = Path()
      ..moveTo(startLine.from.dx, startLine.from.dy)
      ..lineTo(startLine.to.dx, startLine.to.dy)
      ..arcTo(sectionRadiusRect, startRadians, sweepRadians, false)
      ..lineTo(endLine.from.dx, endLine.from.dy)
      ..arcTo(centerRadiusRect, endRadians, -sweepRadians, false)
      ..moveTo(startLine.from.dx, startLine.from.dy)
      ..close();

    /// Subtract section space from the sectionPath
    if (sectionSpace != 0) {
      final startLineSeparatorPath = createRectPathAroundLine(startLine, sectionSpace);
      sectionPath = Path.combine(
          PathOperation.difference, sectionPath, startLineSeparatorPath);

      final endLineSeparatorPath = createRectPathAroundLine(endLine, sectionSpace);
      sectionPath = Path.combine(
          PathOperation.difference, sectionPath, endLineSeparatorPath);
    }

    /// Adds rounded corners to the pie chart data
    if (roundedCornerRadius != 0 && roundedCornerDegrees != 0) {
      final cornerCutout = createRoundedCornerCutout(roundedCornerDegrees,
          roundedCornerRadius, center, startLineFrom, startLineTo, startRadians,
          endLineFrom, endLineTo, endRadians, centerRadius, section.radius);
      sectionPath = Path.combine(
          PathOperation.difference, sectionPath, cornerCutout);
    }

    return sectionPath;
  }

  /// Creates a rect around a narrow line
  @visibleForTesting
  Path createRectPathAroundLine(Line line, double width) {
    width = width / 2;
    final normalized = line.normalize();

    final verticalAngle = line.direction() + (math.pi / 2);
    final verticalDirection =
        Offset(math.cos(verticalAngle), math.sin(verticalAngle));

    final startPoint1 = Offset(
      line.from.dx -
          (normalized * (width / 2)).dx -
          (verticalDirection * width).dx,
      line.from.dy -
          (normalized * (width / 2)).dy -
          (verticalDirection * width).dy,
    );

    final startPoint2 = Offset(
      line.to.dx +
          (normalized * (width / 2)).dx -
          (verticalDirection * width).dx,
      line.to.dy +
          (normalized * (width / 2)).dy -
          (verticalDirection * width).dy,
    );

    final startPoint3 = Offset(
      startPoint2.dx + (verticalDirection * (width * 2)).dx,
      startPoint2.dy + (verticalDirection * (width * 2)).dy,
    );

    final startPoint4 = Offset(
      startPoint1.dx + (verticalDirection * (width * 2)).dx,
      startPoint1.dy + (verticalDirection * (width * 2)).dy,
    );

    return Path()
      ..moveTo(startPoint1.dx, startPoint1.dy)
      ..lineTo(startPoint2.dx, startPoint2.dy)
      ..lineTo(startPoint3.dx, startPoint3.dy)
      ..lineTo(startPoint4.dx, startPoint4.dy)
      ..lineTo(startPoint1.dx, startPoint1.dy);
  }

  Path createRoundedCornerCutout(
      double roundedCornerDegrees,
      double roundedCornerRadius,
      Offset center,
      Offset startLineFrom,
      Offset startLineTo,
      double startRadians,
      Offset endLineFrom,
      Offset endLineTo,
      double endRadians,
      double centerRadius,
      double sectionRadius) {
    final radius = Radius.circular(roundedCornerRadius);
    final radians = Utils().radians(roundedCornerDegrees);
    // Add extra 2 pixel margin to fix numeric issues.
    final largeRadius = Radius.circular(centerRadius + sectionRadius + 10);

    final cStartRadians = startRadians + radians;
    final cStartLineDirection = Offset(math.cos(cStartRadians), math.sin(cStartRadians));
    final cStartLineFrom = center + cStartLineDirection * centerRadius;
    final cStartLineTo = cStartLineFrom + cStartLineDirection * sectionRadius;

    final startCorner = Path()
      ..moveTo(cStartLineTo.dx, cStartLineTo.dy)
      ..arcToPoint(startLineTo, radius: largeRadius, clockwise: false)
      ..lineTo(startLineFrom.dx, startLineFrom.dy)
      ..lineTo(cStartLineFrom.dx, cStartLineFrom.dy)
      ..arcToPoint(cStartLineTo, radius: radius)
      ..close();

    final cEndRadians = endRadians - radians;
    final cEndLineDirection = Offset(math.cos(cEndRadians), math.sin(cEndRadians));
    final cEndLineFrom = center + cEndLineDirection * centerRadius;
    final cEndLineTo = cEndLineFrom + cEndLineDirection * sectionRadius;

    final endCorner = Path()
      ..moveTo(cEndLineTo.dx, cEndLineTo.dy)
      ..arcToPoint(endLineTo, radius: largeRadius)
      ..lineTo(endLineFrom.dx, endLineFrom.dy)
      ..lineTo(cEndLineFrom.dx, cEndLineFrom.dy)
      ..arcToPoint(cEndLineTo, radius: radius, clockwise: false)
      ..close();

    return Path.combine(PathOperation.union, endCorner, startCorner);
  }

  @visibleForTesting
  void drawSection(PieChartSectionData section, Path sectionPath,
      CanvasWrapper canvasWrapper) {
    _sectionPaint.setColorOrGradient(
        section.color,
        section.gradient,
        sectionPath.getBounds(),
    );
    _sectionPaint.style = PaintingStyle.fill;
    canvasWrapper.drawPath(sectionPath, _sectionPaint);
  }

  @visibleForTesting
  void drawSectionStroke(PieChartSectionData section, Path sectionPath,
      CanvasWrapper canvasWrapper, Size viewSize) {
    if (section.borderSide.width != 0.0 &&
        section.borderSide.color.opacity != 0.0) {
      canvasWrapper.saveLayer(
          Rect.fromLTWH(0, 0, viewSize.width, viewSize.height), Paint());
      canvasWrapper.clipPath(sectionPath);

      _sectionStrokePaint.strokeWidth = section.borderSide.width * 2;
      _sectionStrokePaint.color = section.borderSide.color;
      canvasWrapper.drawPath(
        sectionPath,
        _sectionStrokePaint,
      );
      canvasWrapper.restore();
    }
  }

  /// Calculates layout of overlaying elements, includes:
  /// - title text
  /// - badge widget positions
  @visibleForTesting
  void drawTexts(
    BuildContext context,
    CanvasWrapper canvasWrapper,
    PaintHolder<PieChartData> holder,
    double centerRadius,
  ) {
    final data = holder.data;
    final viewSize = canvasWrapper.size;
    final center = Offset(viewSize.width / 2, viewSize.height / 2);

    var tempAngle = data.startDegreeOffset;

    for (var i = 0; i < data.sections.length; i++) {
      final section = data.sections[i];
      final startAngle = tempAngle;
      final sweepAngle = 360 * (section.value / data.sumValue);
      final sectionCenterAngle = startAngle + (sweepAngle / 2);

      Offset sectionCenter(double percentageOffset) =>
          center +
          Offset(
            math.cos(Utils().radians(sectionCenterAngle)) *
                (centerRadius + (section.radius * percentageOffset)),
            math.sin(Utils().radians(sectionCenterAngle)) *
                (centerRadius + (section.radius * percentageOffset)),
          );

      final sectionCenterOffsetTitle =
          sectionCenter(section.titlePositionPercentageOffset);

      if (section.showTitle) {
        final span = TextSpan(
          style: Utils().getThemeAwareTextStyle(context, section.titleStyle),
          text: section.title,
        );
        final tp = TextPainter(
            text: span,
            textAlign: TextAlign.center,
            textDirection: TextDirection.ltr,
            textScaleFactor: holder.textScale);

        tp.layout();
        canvasWrapper.drawText(
            tp, sectionCenterOffsetTitle - Offset(tp.width / 2, tp.height / 2));
      }

      tempAngle += sweepAngle;
    }
  }

  /// Calculates center radius based on the provided sections radius
  @visibleForTesting
  double calculateCenterRadius(
      Size viewSize, PaintHolder<PieChartData> holder) {
    final data = holder.data;
    if (data.centerSpaceRadius.isFinite) {
      return data.centerSpaceRadius;
    }
    final maxRadius =
        data.sections.reduce((a, b) => a.radius > b.radius ? a : b).radius;
    return (viewSize.shortestSide - (maxRadius * 2)) / 2;
  }

  /// Makes a [PieTouchedSection] based on the provided [localPosition]
  ///
  /// Processes [localPosition] and checks
  /// the elements of the chart that are near the offset,
  /// then makes a [PieTouchedSection] from the elements that has been touched.
  PieTouchedSection handleTouch(
    Offset localPosition,
    Size viewSize,
    PaintHolder<PieChartData> holder,
  ) {
    final data = holder.data;
    final sectionsAngle = calculateSectionsAngle(data.sections, data.sumValue);

    final center = Offset(viewSize.width / 2, viewSize.height / 2);

    final touchedPoint2 = localPosition - center;

    final touchX = touchedPoint2.dx;
    final touchY = touchedPoint2.dy;

    final touchR = math.sqrt(math.pow(touchX, 2) + math.pow(touchY, 2));
    var touchAngle = Utils().degrees(math.atan2(touchY, touchX));
    touchAngle = touchAngle < 0 ? (180 - touchAngle.abs()) + 180 : touchAngle;

    PieChartSectionData? foundSectionData;
    var foundSectionDataPosition = -1;

    /// Find the nearest section base on the touch spot
    final relativeTouchAngle = (touchAngle - data.startDegreeOffset) % 360;
    var tempAngle = 0.0;
    for (var i = 0; i < data.sections.length; i++) {
      final section = data.sections[i];
      var sectionAngle = sectionsAngle[i];

      tempAngle %= 360;
      if (data.sections.length == 1) {
        sectionAngle = 360;
      } else {
        sectionAngle %= 360;
      }

      /// degree criteria
      final space = data.sectionsSpace / 2;
      final fromDegree = tempAngle + space;
      final toDegree = sectionAngle + tempAngle - space;
      final isInDegree =
          relativeTouchAngle >= fromDegree && relativeTouchAngle <= toDegree;

      /// radius criteria
      final centerRadius = calculateCenterRadius(viewSize, holder);
      final sectionRadius = centerRadius + section.radius;
      final isInRadius = touchR > centerRadius && touchR <= sectionRadius;

      if (isInDegree && isInRadius) {
        foundSectionData = section;
        foundSectionDataPosition = i;
        break;
      }

      tempAngle += sectionAngle;
    }

    return PieTouchedSection(
        foundSectionData, foundSectionDataPosition, touchAngle, touchR);
  }

  /// Exposes offset for laying out the badge widgets upon the chart.
  Map<int, Offset> getBadgeOffsets(
      Size viewSize, PaintHolder<PieChartData> holder) {
    final data = holder.data;
    final center = viewSize.center(Offset.zero);
    final badgeWidgetsOffsets = <int, Offset>{};

    if (data.sections.isEmpty) {
      return badgeWidgetsOffsets;
    }

    var tempAngle = data.startDegreeOffset;

    final sectionsAngle = calculateSectionsAngle(data.sections, data.sumValue);
    for (var i = 0; i < data.sections.length; i++) {
      final section = data.sections[i];
      final startAngle = tempAngle;
      final sweepAngle = sectionsAngle[i];
      final sectionCenterAngle = startAngle + (sweepAngle / 2);
      final centerRadius = calculateCenterRadius(viewSize, holder);

      Offset sectionCenter(double percentageOffset) =>
          center +
          Offset(
            math.cos(Utils().radians(sectionCenterAngle)) *
                (centerRadius + (section.radius * percentageOffset)),
            math.sin(Utils().radians(sectionCenterAngle)) *
                (centerRadius + (section.radius * percentageOffset)),
          );

      final sectionCenterOffsetBadgeWidget =
          sectionCenter(section.badgePositionPercentageOffset);

      badgeWidgetsOffsets[i] = sectionCenterOffsetBadgeWidget;

      tempAngle += sweepAngle;
    }

    return badgeWidgetsOffsets;
  }
}
