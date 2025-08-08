// lib/features/forecast/utils/export_functionality.dart

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Data model for chart points - matches your existing structure
class ChartDataPoint {
  final DateTime time;
  final double flow;
  final double? confidence;
  final Map<String, dynamic>? metadata;

  const ChartDataPoint({
    required this.time,
    required this.flow,
    this.confidence,
    this.metadata,
  });
}

class ExportFunctionality {
  static final ScreenshotController _screenshotController =
      ScreenshotController();

  /// Share chart as image via platform share sheet
  static Future<void> shareChartImage({
    required Widget chartWidget,
    required String reachName,
    required String forecastType,
    required BuildContext context,
  }) async {
    try {
      // Get MediaQuery data from the current context
      final mediaQueryData = MediaQuery.of(context);

      // Capture chart as image with title and metadata
      final imageBytes = await _screenshotController.captureFromWidget(
        MediaQuery(
          data: mediaQueryData,
          child: Material(
            child: Container(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Add title to the exported image
                  Text(
                    '$reachName - ${_formatForecastType(forecastType)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Chart widget
                  SizedBox(width: 800, height: 400, child: chartWidget),
                  const SizedBox(height: 8),
                  Text(
                    'Generated on ${_formatDateTime(DateTime.now())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        pixelRatio: 2.0,
      );

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final fileName = _generateFileName(
        'chart',
        reachName,
        forecastType,
        'png',
      );
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '$reachName Flow Forecast - ${_formatForecastType(forecastType)}',
        subject: 'Flow Forecast Chart',
      );

      HapticFeedback.lightImpact();
    } catch (e) {
      print('Error sharing chart: $e');
      rethrow;
    }
  }

  /// Save chart image to device gallery
  static Future<void> saveChartToGallery({
    required Widget chartWidget,
    required String reachName,
    required String forecastType,
    required BuildContext context,
  }) async {
    try {
      // Request storage permission
      final permission = await Permission.photos.request();
      if (!permission.isGranted) {
        throw Exception('Storage permission denied');
      }

      // Get MediaQuery data from the current context
      final mediaQueryData = MediaQuery.of(context);

      // Capture chart as image
      final imageBytes = await _screenshotController.captureFromWidget(
        MediaQuery(
          data: mediaQueryData,
          child: Material(
            child: Container(
              color: CupertinoColors.systemBackground.resolveFrom(context),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$reachName - ${_formatForecastType(forecastType)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(width: 800, height: 400, child: chartWidget),
                  const SizedBox(height: 8),
                  Text(
                    'Generated on ${_formatDateTime(DateTime.now())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        pixelRatio: 2.0,
      );

      // Save to temporary file first
      final tempDir = await getTemporaryDirectory();
      final fileName = _generateFileName(
        'chart',
        reachName,
        forecastType,
        'png',
      );
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      // Save to gallery using Gal
      await Gal.putImage(file.path);

      HapticFeedback.lightImpact();
    } catch (e) {
      print('Error saving chart to gallery: $e');
      rethrow;
    }
  }

  /// Export chart data as CSV file
  static Future<void> exportDataAsCSV({
    required List<ChartDataPoint> chartData,
    required String reachName,
    required String forecastType,
    required Map<int, double>? returnPeriods,
  }) async {
    try {
      // Prepare CSV data
      final List<List<dynamic>> csvData = [];

      // Add header with metadata
      csvData.add(['Flow Forecast Data Export']);
      csvData.add(['Reach Name', reachName]);
      csvData.add(['Forecast Type', _formatForecastType(forecastType)]);
      csvData.add(['Export Date', _formatDateTime(DateTime.now())]);
      csvData.add(['Total Data Points', chartData.length.toString()]);
      csvData.add([]); // Empty row

      // Add main data header
      csvData.add(['Date/Time', 'Flow (CFS)', 'Confidence']);

      // Add chart data rows
      for (final point in chartData) {
        csvData.add([
          point.time.toIso8601String(),
          point.flow.toStringAsFixed(2),
          point.confidence?.toStringAsFixed(3) ?? 'N/A',
        ]);
      }

      // Add return periods data if available
      if (returnPeriods != null && returnPeriods.isNotEmpty) {
        csvData.add([]); // Empty row separator
        csvData.add(['Return Periods (Flood Categories)']);
        csvData.add(['Return Period (Years)', 'Flow Threshold (CFS)']);

        // Convert CMS to CFS if needed (assuming your return periods are in CMS)
        const cmsToCs = 35.3147;
        final sortedPeriods = returnPeriods.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        for (final entry in sortedPeriods) {
          csvData.add([
            '${entry.key} year',
            (entry.value * cmsToCs).toStringAsFixed(2),
          ]);
        }
      }

      // Convert to CSV string
      final csvString = const ListToCsvConverter().convert(csvData);

      // Save to app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final fileName = _generateFileName(
        'forecast_data',
        reachName,
        forecastType,
        'csv',
      );
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvString);

      // Share the CSV file
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            '$reachName Flow Forecast Data - ${_formatForecastType(forecastType)}',
        subject: 'Flow Forecast Data (CSV)',
      );

      HapticFeedback.lightImpact();
    } catch (e) {
      print('Error exporting CSV: $e');
      rethrow;
    }
  }

  /// Show success message to user
  static void showSuccessMessage(BuildContext context, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Icon(
          CupertinoIcons.checkmark_circle_fill,
          color: CupertinoColors.systemGreen,
          size: 32,
        ),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Show error message to user
  static void showErrorMessage(BuildContext context, String error) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          color: CupertinoColors.systemRed,
          size: 32,
        ),
        content: Text('Export failed: $error'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  /// Helper methods
  static String _formatForecastType(String forecastType) {
    switch (forecastType) {
      case 'short_range':
        return 'Short Range Forecast';
      case 'medium_range':
        return 'Medium Range Forecast';
      case 'long_range':
        return 'Long Range Forecast';
      case 'analysis_assimilation':
        return 'Current Analysis';
      case 'medium_range_blend':
        return 'Medium Range Blend';
      default:
        return forecastType.toUpperCase();
    }
  }

  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  static String _generateFileName(
    String prefix,
    String reachName,
    String forecastType,
    String extension,
  ) {
    final cleanReachName = reachName
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_${cleanReachName}_${forecastType}_$timestamp.$extension';
  }
}
