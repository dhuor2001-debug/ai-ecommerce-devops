import json, os, unittest
import analyze

HERE = os.path.dirname(__file__)
def sample(n):
    with open(os.path.join(HERE, "samples", n)) as f:
        return f.read()
def run(text): return analyze.analyze_offline([analyze.redact(l) for l in analyze.extract_errors(text)])

class OfflineAnalysis(unittest.TestCase):
    def test_report_example_database_timeout(self):
        r = run(sample("db-timeout.log"))
        self.assertEqual(r["category"], "Database connectivity")
        self.assertEqual(r["severity"], "high")
        self.assertIn("connectivity", r["root_cause"].lower())
        joined = " ".join(r["investigation"]).lower()
        for topic in ("availability", "network", "credentials", "connection limits"):
            self.assertIn(topic, joined)

    def test_oom_and_crashloop_pick_most_severe(self):
        r = run(sample("oom.log"))
        self.assertEqual(r["category"], "Crash loop / restart storm")   # critical beats high
        self.assertIn("Out of memory", r["other_categories"])

    def test_unknown_error_is_low_severity(self):
        self.assertEqual(run("ERROR something odd happened")["severity"], "low")

class Redaction(unittest.TestCase):
    def test_secrets_never_survive(self):
        t = analyze.redact(sample("db-timeout.log") + sample("injection.log"))
        for leak in ("S3cretPass", "10.0.3.7", "192.168.1.5", "hunter2hunter2"):
            self.assertNotIn(leak, t)

    def test_aws_key_and_bearer(self):
        t = analyze.redact("key=AKIAIOSFODNN7EXAMPLE Authorization: Bearer abcdefghijklmnop12345")
        self.assertNotIn("AKIAIOSFODNN7EXAMPLE", t); self.assertNotIn("abcdefghijklmnop12345", t)

class ModelOutputValidation(unittest.TestCase):
    fb = analyze.FALLBACK
    def test_bad_severity_falls_back(self):
        r = analyze.validate({"severity": "apocalyptic", "category": "x"}, self.fb, "m")
        self.assertEqual(r["severity"], self.fb["severity"])
    def test_non_list_fields_fall_back(self):
        r = analyze.validate({"investigation": "run rm -rf /", "remediation": None}, self.fb, "m")
        self.assertEqual(r["investigation"], self.fb["investigation"])
    def test_lists_are_truncated(self):
        r = analyze.validate({"investigation": ["a"] * 50}, self.fb, "m")
        self.assertLessEqual(len(r["investigation"]), 6)

class InjectionResistance(unittest.TestCase):
    def test_injection_line_is_only_data(self):
        r = run(sample("injection.log"))
        self.assertEqual(r["category"], "Database connectivity")
        # the tool only reports; it has no code path that executes anything from logs
        self.assertNotIn("delete", " ".join(r["remediation"]).lower())

if __name__ == "__main__":
    unittest.main()
