import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../state/app_state.dart';

class UploadRaportScreen extends StatefulWidget {
  const UploadRaportScreen({super.key});

  @override
  State<UploadRaportScreen> createState() => _UploadRaportScreenState();
}

class _UploadRaportScreenState extends State<UploadRaportScreen> {
  bool _parsing = false;
  bool _applying = false;
  String? _error;
  String? _groupName;
  int? _groupYear;
  List<String>? _students;

  Future<void> _pickAndParse() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
    );
    if (files.isEmpty) return;
    final path = files.single.path;
    if (path == null) return;

    setState(() {
      _parsing = true;
      _error = null;
    });
    try {
      if (!mounted) return;
      final data =
          await context.read<AppState>().api.uploadRaport(File(path));
      if (!mounted) return;
      setState(() {
        _groupName = data['group_name'];
        _groupYear = data['group_year'];
        _students = (data['students'] as List).cast<String>();
        _parsing = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _parsing = false;
        _error = e.message;
      });
    }
  }

  Future<void> _apply() async {
    setState(() {
      _applying = true;
      _error = null;
    });
    try {
      final res = await context
          .read<AppState>()
          .api
          .applyRaport(
            groupName: _groupName ?? '',
            year: _groupYear,
            students: _students ?? [],
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Группа обновлена: ${res['students_count']} студентов')),
      );
      final state = context.read<AppState>();
      final groups = await state.api.getGroups();
      state.setGroup(groups.firstWhere(
        (g) => g.id == res['group_id'],
        orElse: () => groups.first,
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _applying = false;
        _error = e.message;
      });
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Загрузить рапортичку')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Выберите файл .docx в формате рапортички '
                '(табличка с ФИО студентов, номером группы и годом). '
                'Из файла будут извлечены: номер группы, год и список студентов.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_parsing)
            const Center(child: CircularProgressIndicator())
          else
            OutlinedButton.icon(
              onPressed: _pickAndParse,
              icon: const Icon(Icons.sd_card),
              label: const Text('Выбрать .docx файл'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_students != null) ...[
            const SizedBox(height: 24),
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Группа: $_groupName',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (_groupYear != null) Text('Год: $_groupYear'),
                    const SizedBox(height: 8),
                    Text('Студенты (${_students!.length}):'),
                    const SizedBox(height: 4),
                    for (int i = 0; i < _students!.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${i + 1}. ${_students![i]}'),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _applying ? null : _apply,
              icon: _applying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: const Text('Применить (создать/обновить группу)'),
            ),
          ],
        ],
      ),
    );
  }
}