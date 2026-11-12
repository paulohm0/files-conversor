import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/path_utils.dart';
import '../../../diagnostics/presentation/diagnostics_cubit.dart';
import '../../../diagnostics/presentation/diagnostics_dialog.dart';
import '../../../settings/domain/app_settings.dart';
import '../../../settings/presentation/settings_cubit.dart';
import '../../domain/contracts/repositories.dart';
import '../../domain/entities/conversion_job.dart';
import '../../domain/entities/target_format.dart';
import '../../domain/usecases/get_available_targets.dart';
import '../cubit/conversion_cubit.dart';
import '../cubit/conversion_state.dart';
import '../cubit/engines_cubit.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/file_list.dart';
import '../widgets/format_bar.dart';
import '../widgets/options_panel.dart';
import '../widgets/status_widgets.dart';

/// Tela única do conversor.
class HomePage extends StatefulWidget {
  const HomePage({
    required this.getTargets,
    required this.dialogs,
    required this.shell,
    required this.createDiagnosticsCubit,
    super.key,
  });

  final GetAvailableTargets getTargets;
  final FileDialogs dialogs;
  final ShellIntegration shell;
  final DiagnosticsCubit Function() createDiagnosticsCubit;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _focus = FocusNode(debugLabel: 'home');
  bool _dragging = false;

  ConversionCubit get _conversion => context.read<ConversionCubit>();
  SettingsCubit get _settings => context.read<SettingsCubit>();
  EnginesCubit get _engines => context.read<EnginesCubit>();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  List<TargetFormat> _targetsFor(ConversionState state) => widget.getTargets(
        state.jobsToConvert.map((j) => j.category),
        _engines.state.availability,
      );

  Future<void> _addFiles() async {
    if (_conversion.state.running) return;
    final paths = await widget.dialogs.pickFiles();
    if (paths.isNotEmpty) _conversion.addPaths(paths);
  }

  Future<void> _browseOutput() async {
    final folder = await widget.dialogs
        .pickFolder(initialDirectory: _settings.state.outputDir);
    if (folder != null) {
      await _settings.update((s) => s.copyWith(outputDir: folder));
    }
  }

  Future<void> _convert(TargetFormat target) async {
    final state = _conversion.state;
    if (state.running || !_targetsFor(state).contains(target)) return;
    final settings = _settings.state;

    if (settings.useOtherFolder && settings.outputDir.trim().isEmpty) {
      await _showMessage('Escolha a pasta de saída.');
      return;
    }

    final items = state.jobsToConvert.where((j) => isExistingFile(j.path));
    if (settings.confirmBeforeConvert && items.isNotEmpty) {
      final answer = await showConfirmDialog(
        context,
        target: target,
        fileNames: [for (final j in items) j.fileName],
        deleteOriginal: settings.deleteOriginal,
      );
      if (!answer.confirmed) return;
      if (answer.dontAskAgain) {
        await _settings
            .update((s) => s.copyWith(confirmBeforeConvert: false));
        _conversion.addLog(
          "Confirmação desativada. Para voltar a pedir, marque 'Pedir "
          "confirmação antes de converter' em Opções.",
        );
      }
    }

    await _settings.update((s) => s.copyWith(lastTarget: target));
    await _conversion.start(
      _settings.state.toOptions(target),
      _engines.state.availability,
      onEngineDisabled: _engines.disable,
    );
  }

  Future<void> _onRunFinished(RunSummary run) async {
    final settings = _settings.state;
    if (settings.openFolderWhenDone && run.ok > 0 && run.folders.isNotEmpty) {
      await widget.shell.openFolder(run.folders.first);
    }
    if (run.failed > 0) {
      await SystemSound.play(SystemSoundType.alert);
      await _settings.update((s) => s.copyWith(showLog: true));
      await _showMessage(
        '${run.failed} arquivo(s) com erro. Os detalhes estão no registro, '
        'aberto na parte de baixo da janela.',
      );
    }
  }

  Future<void> _open(ConversionJob job) async {
    final output = job.outputPath;
    final target = output != null && isExistingFile(output)
        ? output
        : (isExistingFile(job.path) ? job.path : null);
    if (target != null) await widget.shell.revealInExplorer(target);
  }

  Future<void> _showDiagnostics() async {
    if (_conversion.state.running) return;
    await showDiagnosticsDialog(
      context,
      createCubit: widget.createDiagnosticsCubit,
      engines: _engines.state.availability,
      onOpenFolder: widget.shell.openFolder,
    );
  }

  Future<void> _showMessage(String message) => showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Conversor'),
          content: Text(message),
          actions: [
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final key = event.logicalKey;
    final running = _conversion.state.running;

    if (ctrl && key == LogicalKeyboardKey.keyO) {
      _addFiles();
    } else if (ctrl && key == LogicalKeyboardKey.keyV) {
      _conversion.addFromClipboard();
    } else if (ctrl && key == LogicalKeyboardKey.keyA) {
      _conversion.selectAll();
    } else if (key == LogicalKeyboardKey.delete) {
      _conversion.removeSelected();
    } else if (key == LogicalKeyboardKey.escape) {
      running ? _conversion.cancel() : _conversion.clearSelection();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _convert(_settings.state.lastTarget);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  String _formatTitle(ConversionState state) {
    final n = state.jobsToConvert.length;
    if (n == 0) return 'Converter para';
    final what = state.hasSelection
        ? 'selecionado(s)'
        : 'pendente(s)/com erro';
    return 'Converter $n arquivo(s) $what para:   '
        '(clique no formato · Enter repete o último)';
  }

  String _emptyMessage(ConversionState state) {
    if (state.jobs.isEmpty) {
      return 'Adicione arquivos para ver os formatos disponíveis.';
    }
    if (state.jobsToConvert.isEmpty) {
      return 'Tudo convertido. Adicione novos arquivos ou selecione itens do '
          'histórico para converter de novo.';
    }
    return 'Nenhum formato em comum para esses arquivos '
        '(ou falta um motor de conversão).';
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ConversionCubit, ConversionState>(
      listenWhen: (a, b) => a.lastRun != b.lastRun && b.lastRun != null,
      listener: (_, state) => _onRunFinished(state.lastRun!),
      child: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _focus.requestFocus,
          child: Scaffold(
            body: BlocBuilder<ConversionCubit, ConversionState>(
              builder: (context, state) {
                return BlocBuilder<SettingsCubit, AppSettings>(
                  builder: (context, settings) {
                    return BlocBuilder<EnginesCubit, EnginesState>(
                      builder: (context, engines) =>
                          _buildBody(state, settings, engines),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    ConversionState state,
    AppSettings settings,
    EnginesState engines,
  ) {
    final running = state.running;
    final targets = _targetsFor(state);
    return DropTarget(
      enable: !running,
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        _conversion.addPaths(details.files.map((f) => f.path));
      },
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Toolbar(
                    enabled: !running,
                    hasSelection: state.hasSelection,
                    hasItems: state.jobs.isNotEmpty,
                    onAdd: _addFiles,
                    onPaste: _conversion.addFromClipboard,
                    onRemove: _conversion.removeSelected,
                    onClear: _conversion.clearList,
                    onDiagnostics: _showDiagnostics,
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          width: 2,
                          color: _dragging
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                      child: state.jobs.isEmpty
                          ? EmptyDropArea(onTap: _addFiles)
                          : FileList(
                              jobs: state.jobs,
                              selectedIds: state.selectedIds,
                              onSelect: (id, {required toggle, required range}) {
                                _focus.requestFocus();
                                _conversion.select(
                                  id,
                                  toggle: toggle,
                                  range: range,
                                );
                              },
                              onOpen: _open,
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FormatBar(
                    targets: targets,
                    lastTarget: settings.lastTarget,
                    title: _formatTitle(state),
                    emptyMessage: _emptyMessage(state),
                    enabled: !running,
                    onConvert: _convert,
                  ),
                  const SizedBox(height: 10),
                  OptionsPanel(
                    settings: settings,
                    enabled: !running,
                    onChanged: _settings.update,
                    onBrowse: _browseOutput,
                  ),
                  const SizedBox(height: 10),
                  ProgressRow(
                    state: state,
                    logVisible: settings.showLog,
                    onCancel: _conversion.cancel,
                    onToggleLog: () => _settings
                        .update((s) => s.copyWith(showLog: !s.showLog)),
                  ),
                  if (settings.showLog) ...[
                    const SizedBox(height: 8),
                    LogPanel(entries: state.log),
                  ],
                ],
              ),
            ),
          ),
          EnginesFooter(
            engines: engines.availability,
            detected: engines.detected,
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.enabled,
    required this.hasSelection,
    required this.hasItems,
    required this.onAdd,
    required this.onPaste,
    required this.onRemove,
    required this.onClear,
    required this.onDiagnostics,
  });

  final bool enabled;
  final bool hasSelection;
  final bool hasItems;
  final VoidCallback onAdd;
  final VoidCallback onPaste;
  final VoidCallback onRemove;
  final VoidCallback onClear;
  final VoidCallback onDiagnostics;

  @override
  Widget build(BuildContext context) {
    Widget tip(String message, Widget child) => Tooltip(
          message: message,
          waitDuration: const Duration(milliseconds: 600),
          child: child,
        );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        tip(
          'Ctrl+O',
          FilledButton.tonalIcon(
            key: const Key('add-files'),
            onPressed: enabled ? onAdd : null,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar arquivos'),
          ),
        ),
        tip(
          'Cole arquivos copiados no Explorer (Ctrl+C lá, Ctrl+V aqui)',
          OutlinedButton.icon(
            onPressed: enabled ? onPaste : null,
            icon: const Icon(Icons.content_paste),
            label: const Text('Colar (Ctrl+V)'),
          ),
        ),
        tip(
          'Tecla Delete',
          OutlinedButton.icon(
            key: const Key('remove-selected'),
            onPressed: enabled && hasSelection ? onRemove : null,
            icon: const Icon(Icons.remove_circle_outline),
            label: const Text('Remover'),
          ),
        ),
        OutlinedButton.icon(
          key: const Key('clear-list'),
          onPressed: enabled && hasItems ? onClear : null,
          icon: const Icon(Icons.clear_all),
          label: const Text('Limpar lista'),
        ),
        const SizedBox(width: 12),
        tip(
          'Autoteste com arquivos de exemplo e relatório',
          TextButton.icon(
            onPressed: enabled ? onDiagnostics : null,
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('Diagnóstico'),
          ),
        ),
      ],
    );
  }
}
