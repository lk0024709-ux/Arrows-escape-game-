import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/generator/difficulty_params.dart';
import '../../game/generator/level_generator.dart';
import '../../game/model/level.dart';
import '../../game/solver/solver.dart';
import '../../theme/app_theme.dart';

/// Developer-only level editor (prompt §57, §58).
///
/// generate → inspect → modify → validate → solve → export
class LevelEditorScreen extends StatefulWidget {
  const LevelEditorScreen({super.key});

  @override
  State<LevelEditorScreen> createState() => _LevelEditorScreenState();
}

class _LevelEditorScreenState extends State<LevelEditorScreen> {
  final LevelGenerator _generator = LevelGenerator();
  final TextEditingController _seedController =
      TextEditingController(text: '12345');
  int _band = DifficultyBand.medium;
  Level? _level;
  String _output = 'Press “Generate” to build a level.';
  bool _busy = false;

  @override
  void dispose() {
    _seedController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    final seed = int.tryParse(_seedController.text) ?? 12345;
    final level = await Future<Level>.microtask(
      () => _generator.generate(difficulty: _band, seed: seed),
    );
    if (!mounted) return;
    setState(() {
      _level = level;
      _output = _summarise(level);
      _busy = false;
    });
  }

  void _validate() {
    final level = _level;
    if (level == null) return;
    final issues = LevelGenerator.validate(level);
    setState(() {
      _output = issues.isEmpty
          ? 'VALID\n\n${_summarise(level)}'
          : 'INVALID\n${issues.map((i) => ' • $i').join('\n')}';
    });
  }

  void _solve() {
    final level = _level;
    if (level == null) return;
    const solver = Solver(mode: SolverMode.bfs, maxNodes: 60000);
    final stopwatch = Stopwatch()..start();
    final solution = solver.solve(level);
    stopwatch.stop();
    setState(() {
      _output = [
        'mode        bfs',
        'complete    ${solution.isComplete}',
        'length      ${solution.length} '
            '(escapes ${solution.moves.where((m) => m.escapes).length}, '
            'slides ${solution.moves.where((m) => !m.escapes).length})',
        'optimal     ${solution.isOptimal}',
        'nodes       ${solution.nodesExplored}',
        'ms          ${stopwatch.elapsedMilliseconds}',
        '',
        ...solution.moves.take(40).toList().asMap().entries.map(
              (e) => '${'${e.key + 1}'.padLeft(2)}. #${e.value.arrowIndex} '
                  '${e.value.escapes ? 'escape' : 'slide'} '
                  '${e.value.travel.toStringAsFixed(2)}',
            ),
      ].join('\n');
    });
  }

  Future<void> _export() async {
    final level = _level;
    if (level == null) return;
    final json = const JsonEncoder.withIndent('  ').convert(level.toJson());
    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) return;
    setState(() {
      _output = 'Copied ${json.length} bytes of JSON.\n\n${_summarise(level)}';
    });
  }

  String _summarise(Level level) {
    final a = level.analysis;
    return [
      'id           ${level.levelId}',
      'seed         ${level.seed}',
      'difficulty   ${level.difficulty} (${a?.difficultyLabel ?? '—'})',
      'quality      ${a?.qualityScore.toStringAsFixed(1) ?? '—'}',
      'grid         ${level.gridCols} x ${level.gridRows}',
      'arrows       ${level.arrowCount}',
      'solution     ${a?.optimalSolutionLength ?? '—'} moves',
      'depth/roots  ${a?.dependencyDepth ?? '—'} / ${a?.rootCount ?? '—'}',
      'decoys       ${a?.decoyMoves ?? '—'}',
      'density      ${a?.spatialDensity.toStringAsFixed(2) ?? '—'}',
      'json         ${jsonEncode(level.toJson()).length} bytes',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Level editor',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _seedController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Seed',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: _band,
                    items: [
                      for (var band = 1; band <= 5; band++)
                        DropdownMenuItem<int>(
                          value: band,
                          child: Text(DifficultyBand.labelOf(band)),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _band = value ?? _band),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _generate,
                      child: const Text('Generate'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: _validate, child: const Text('Validate'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: _solve, child: const Text('Solve'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: _export, child: const Text('Export'))),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.lightUi,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _output,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.5,
                      color: AppColors.navySoft,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
