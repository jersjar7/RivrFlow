// lib/features/forecast/utils/export_functionality.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:csv/csv.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ExportFunctionality {
  static final ScreenshotController _screenshotController =
      ScreenshotController();

  /// Share chart as image via platform share sheet
  static Future<void> shareChartImage({
    required Widget chartWidget,
    required String reachName,
    required String forecastType,
  }) async {
    try {
      // Capture chart as image
      final imageBytes = await _screenshotController.captureFromWidget(
        Container(
          color: CupertinoColors.systemBackground,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add title to the exported image
              Text(
                '$reachName - ${_formatForecastType(forecastType)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 16),
              chartWidget,
              const SizedBox(height: 8),
              Text(
                'Generated on ${DateTime.now().toString().substring(0, 16)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
        pixelRatio: 2.0,
      );

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'chart_${reachName}_${forecastType}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '$reachName Flow Forecast - $forecastType',
        subject: 'Flow Forecast Chart',
      );

      HapticFeedback.lightImpact();
    } catch (e) {
      print('Error sharing chart: $e');
      throw Exception('Failed to share chart');
    }
  }

  /// Save chart image to device gallery
  static Future<void> saveChartToGallery({
    required Widget chartWidget,
    required String reachName,
    required String forecastType,
  }) async {
    try {
      // Request storage permission
      final permission = await Permission.photos.request();
      if (!permission.isGranted) {
        throw Exception('Storage permission denied');
      }

      // Capture chart as image
      final imageBytes = await _screenshotController.captureFromWidget(
        Container(
          color: CupertinoColors.systemBackground,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add title to the exported image
              Text(
                '$reachName - ${_formatForecastType(forecastType)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.label,
                ),
              ),
              const SizedBox(height: 16),
              chartWidget,
              const SizedBox(height: 8),
              Text(
                'Generated on ${DateTime.now().toString().substring(0, 16)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
              ),
            ],
          ),
        ),
        pixelRatio: 2.0,
      );

      // Save to temporary file first
      final tempDir = await getTemporaryDirectory();
      final fileName =
          'chart_${reachName}_${forecastType}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      // Save to gallery
      final result = await Gal.(file.path);

      if (result == true) {
        HapticFeedback.lightImpact();
      } else {
        throw Exception('Failed to save to gallery');
      }
    } catch (e) {
      print('Error saving chart to gallery: $e');
      throw Exception('Failed to save chart to gallery');
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

      // Add header row
      csvData.add(['Date/Time', 'Flow (CFS)', 'Forecast Type', 'Reach Name']);

      // Add chart data rows
      for (final point in chartData) {
        csvData.add([
          point.time.toIso8601String(),
          point.flow.toStringAsFixed(2),
          forecastType,
          reachName,
        ]);
      }

      // Add return periods data if available
      if (returnPeriods != null && returnPeriods.isNotEmpty) {
        csvData.add(['']); // Empty row separator
        csvData.add(['Return Periods']); // Section header
        csvData.add(['Years', 'Flow (CFS)']);

        const cmsToCs = 35.3147; // Convert CMS to CFS
        for (final entry in returnPeriods.entries) {
          csvData.add([
            '${entry.key} year',
            (entry.value * cmsToCs).toStringAsFixed(2),
          ]);
        }
      }

      // Convert to CSV string
      final csvString = const ListToCsvConverter().convert(csvData);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'forecast_data_${reachName}_${forecastType}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvString);

      // Share the CSV file
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '$reachName Flow Forecast Data - $forecastType',
        subject: 'Flow Forecast Data (CSV)',
      );

      HapticFeedback.lightImpact();
    } catch (e) {
      print('Error exporting CSV: $e');
      throw Exception('Failed to export CSV data');
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

  /// Format forecast type for display
  static String _formatForecastType(String forecastType) {
    switch (forecastType) {
      case 'short_range':
        return 'Short Range Forecast';
      case 'medium_range':
        return 'Medium Range Forecast';
      case 'long_range':
        return 'Long Range Forecast';
      default:
        return forecastType.toUpperCase();
    }
  }
}

/// Data model for chart points (ensure this matches your existing model)
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
