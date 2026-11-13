import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
import analyze  # noqa: E402


def make_data(n_pairs=8, n_probes=20, seed=0):
    """Petite matrice artificielle : le probe_0 est plus exprimé dans les tumeurs."""
    rng = np.random.default_rng(seed)
    rows = []
    for i in range(1, n_pairs + 1):
        pid = f"P{i:02d}"
        rows.append({"sample_id": f"{pid}N", "condition": "Normal", "patient_id": pid})
        rows.append({"sample_id": f"{pid}T", "condition": "Tumor", "patient_id": pid})
    meta = pd.DataFrame(rows)
    data = rng.normal(8, 1, size=(n_probes, len(meta)))
    expr = pd.DataFrame(
        data,
        index=[f"probe_{i}" for i in range(n_probes)],
        columns=meta["sample_id"],
    )
    tumor_cols = meta.loc[meta.condition == "Tumor", "sample_id"]
    expr.loc["probe_0", tumor_cols] += 5
    return expr, meta


class TestAnalysis(unittest.TestCase):

    def test_valid_pairs_accepted(self):
        expr, meta = make_data()
        analyze.validate_pairs(expr, meta)  # ne doit pas lever d'erreur

    def test_missing_pair_member_rejected(self):
        expr, meta = make_data()
        meta = meta[meta.sample_id != "P01T"]
        expr = expr.drop(columns=["P01T"])
        with self.assertRaises(SystemExit):
            analyze.validate_pairs(expr, meta)

    def test_wrong_condition_rejected(self):
        expr, meta = make_data()
        meta.loc[meta.sample_id == "P01N", "condition"] = "Tumor"
        with self.assertRaises(SystemExit):
            analyze.validate_pairs(expr, meta)

    def test_matrix_metadata_mismatch_rejected(self):
        expr, meta = make_data()
        expr = expr.rename(columns={"P01N": "AUTRE"})
        with self.assertRaises(SystemExit):
            analyze.validate_pairs(expr, meta)

    def test_results_columns(self):
        expr, meta = make_data()
        res = analyze.paired_test(expr, meta)
        res = analyze.adjust_fdr(res, 0.05, 1.0)
        for col in ("probe_id", "mean_tumor", "mean_normal", "log2fc",
                    "statistic", "p_value", "fdr", "significant"):
            self.assertIn(col, res.columns)

    def test_pvalues_and_fdr_in_range(self):
        expr, meta = make_data()
        res = analyze.adjust_fdr(analyze.paired_test(expr, meta), 0.05, 1.0)
        self.assertTrue(res["p_value"].between(0, 1).all())
        self.assertTrue(res["fdr"].between(0, 1).all())

    def test_known_probe_detected(self):
        expr, meta = make_data()
        res = analyze.adjust_fdr(analyze.paired_test(expr, meta), 0.05, 1.0)
        self.assertEqual(res.iloc[0]["probe_id"], "probe_0")
        self.assertGreater(res.iloc[0]["log2fc"], 0)

    def test_output_files_created(self):
        expr, meta = make_data()
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            expr.to_csv(tmp / "expr.csv")
            meta.to_csv(tmp / "meta.csv", index=False)
            out_csv = tmp / "tables" / "res.csv"
            out_fig = tmp / "figures"
            proc = subprocess.run(
                [sys.executable, str(ROOT / "scripts" / "analyze.py"),
                 "--matrix", str(tmp / "expr.csv"),
                 "--metadata", str(tmp / "meta.csv"),
                 "--out-table", str(out_csv),
                 "--out-figures", str(out_fig)],
                capture_output=True, text=True,
            )
            self.assertEqual(proc.returncode, 0, proc.stderr)
            self.assertTrue(out_csv.is_file() and out_csv.stat().st_size > 0)
            self.assertTrue((out_fig / "volcano_plot.png").is_file())

    def test_missing_input_file_fails(self):
        proc = subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "analyze.py"),
             "--matrix", "inexistant.csv", "--metadata", "inexistant.csv",
             "--out-table", "x.csv", "--out-figures", "x"],
            capture_output=True, text=True,
        )
        self.assertNotEqual(proc.returncode, 0)


if __name__ == "__main__":
    unittest.main()
