"""Execute offline numerical, storage and mocked instrument tests; no VISA I/O."""
from pathlib import Path
import contextlib
import datetime
import io
import json
import unittest

def main():
    root = Path(__file__).resolve().parent
    print("Running offline Python tests. No instrument connections will be opened.", flush=True)
    log = io.StringIO()
    with contextlib.redirect_stdout(log), contextlib.redirect_stderr(log):
        suite = unittest.defaultTestLoader.discover(str(root/"tests"), top_level_dir=str(root))
        result = unittest.TextTestRunner(stream=log, verbosity=2).run(suite)
    folder = root/"validation"
    folder.mkdir(exist_ok=True)
    (folder/"offline_tests.log").write_text(log.getvalue(), encoding="utf-8")
    report = dict(testedAt=datetime.datetime.now().astimezone().isoformat(),
                  testMethodsRun=result.testsRun, failures=len(result.failures),
                  errors=len(result.errors), skipped=len(result.skipped), passed=result.wasSuccessful(),
                  hardwareTested=False)
    (folder/"offline_tests.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    print("Details:", folder/"offline_tests.log")
    if not result.wasSuccessful(): print(log.getvalue()[-12000:])
    return 0 if result.wasSuccessful() else 1
if __name__ == "__main__":
    raise SystemExit(main())
