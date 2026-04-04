test:
    @for f in tests/test_*.lua; do luajit "$f" || exit 1; done
