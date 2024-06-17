
import 'dart:async';
import 'dart:math';

class TaskScheduler {
  final Completer<void> _completer = Completer<void>();
  Future Function() task;
  bool isDispose = false;
  int _taskExecutionCount = 0;
  Stopwatch stopwatch = Stopwatch();

  TaskScheduler({required this.task});

  void start() {
    stopwatch.start();
    _completer.future.then((_) => _scheduleTask());
  }

  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  void dispose() {
    isDispose = true;
  }

  void _scheduleTask() {
    if (isDispose) return;

    _taskExecutionCount += 1;
    _executeTask();

    // Calculate delay time
    final fixedIncrement = 10 * _taskExecutionCount;
    final exponentialDelay = pow(2, _taskExecutionCount).toInt();
    final delaySeconds = min(fixedIncrement + exponentialDelay, 3600); // Max 1 hour

    Future.delayed(Duration(seconds: delaySeconds), _scheduleTask);
  }

  void _executeTask() {
    if (isDispose) return;
    task();
  }
}
