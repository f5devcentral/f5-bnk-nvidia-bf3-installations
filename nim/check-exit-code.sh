kubectl get pod -n nim my-nim-nim-llm-0 \
  -o jsonpath='{range .status.containerStatuses[*]}{.name}{"\n  restartCount="}{.restartCount}{"\n  lastReason="}{.lastState.terminated.reason}{"\n  lastExitCode="}{.lastState.terminated.exitCode}{"\n  lastMsg="}{.lastState.terminated.message}{"\n\n"}{end}'
