import argparse
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import stats
from statsmodels.stats.multitest import multipletests

PAIR_COL = "patient_id"   # colonne des métadonnées qui identifie le patient (la paire)


def parse_args():
    p = argparse.ArgumentParser(description="Analyse différentielle appariée GSE15852")
    p.add_argument("--matrix", default="data/processed/expression_matrix.csv")
    p.add_argument("--metadata", default="data/processed/sample_metadata.csv")
    p.add_argument("--annotation", default="data/processed/probe_annotation.csv")
    p.add_argument("--out-table", default="results/tables/differentially_expressed_genes.csv")
    p.add_argument("--out-figures", default="results/figures")
    p.add_argument("--fdr", type=float, default=0.05)
    p.add_argument("--lfc", type=float, default=1.0)
    return p.parse_args()


def die(msg):
    print(f"[ERREUR] {msg}", file=sys.stderr)
    sys.exit(1)


def load_data(matrix_path, meta_path, annot_path=None):
    paths = [matrix_path, meta_path] + ([annot_path] if annot_path else [])
    for f in paths:
        if not Path(f).is_file():
            die(f"Fichier introuvable : {f}")
    expr = pd.read_csv(matrix_path, index_col=0, encoding="utf-8")
    meta = pd.read_csv(meta_path, encoding="utf-8")
    annot = pd.read_csv(annot_path, encoding="utf-8") if annot_path else None
    return expr, meta, annot


def validate_pairs(expr, meta):
    for col in ("sample_id", "condition", PAIR_COL):
        if col not in meta.columns:
            die(f"Colonne manquante dans les métadonnées : {col}")
    if meta["sample_id"].duplicated().any():
        die("Échantillons dupliqués dans les métadonnées.")
    if set(expr.columns) != set(meta["sample_id"]):
        die("Les colonnes de la matrice ne correspondent pas aux métadonnées.")
    if expr.index.duplicated().any():
        die("Identifiants de sondes dupliqués dans la matrice.")
    groups = meta.groupby(PAIR_COL)["condition"].agg(lambda s: sorted(s))
    bad = groups[groups.apply(lambda x: x != ["Normal", "Tumor"])]
    if len(bad) > 0:
        die(f"Paires incomplètes ou incorrectes : {list(bad.index)}")
    if not all(np.issubdtype(t, np.number) for t in expr.dtypes):
        die("Valeurs non numériques dans la matrice.")
    if expr.isna().any().any():
        die("Valeurs manquantes dans la matrice.")


def to_log2(expr):
    print(f"[INFO] Valeur maximale de la matrice : {expr.values.max():.1f}")
    if expr.values.max() > 30:
        print("[INFO] Valeurs brutes détectées. Application de log2(x + 1)...")
        expr = np.log2(expr.clip(lower=0) + 1)
        print("[OK] Transformation appliquée.")
        return expr
    print("[INFO] Valeurs déjà en échelle log : aucune transformation.")
    return expr


def paired_test(expr, meta):
    tumor = meta[meta.condition == "Tumor"].set_index(PAIR_COL)["sample_id"]
    normal = meta[meta.condition == "Normal"].set_index(PAIR_COL)["sample_id"]
    pairs = sorted(tumor.index)
    T = expr[[tumor[p] for p in pairs]].to_numpy()
    N = expr[[normal[p] for p in pairs]].to_numpy()
    stat, pval = stats.ttest_rel(T, N, axis=1)
    return pd.DataFrame({
        "probe_id": expr.index,
        "mean_tumor": T.mean(axis=1),
        "mean_normal": N.mean(axis=1),
        "log2fc": (T - N).mean(axis=1),
        "statistic": stat,
        "p_value": pval,
    })


def adjust_fdr(res, fdr_thr, lfc_thr):
    ok = res["p_value"].notna()
    res["fdr"] = np.nan
    res.loc[ok, "fdr"] = multipletests(res.loc[ok, "p_value"], method="fdr_bh")[1]
    res["significant"] = (res["fdr"] < fdr_thr) & (res["log2fc"].abs() >= lfc_thr)
    return res.sort_values("fdr").reset_index(drop=True)


def add_annotation(res, annot):
    if annot is None:
        return res
    return res.merge(annot, on="probe_id", how="left")


def make_volcano(res, out_dir, fdr_thr, lfc_thr):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    y = -np.log10(res["fdr"].fillna(1).clip(lower=1e-300))
    colors = np.where(res["significant"], "red", "grey")
    plt.figure(figsize=(7, 6))
    plt.scatter(res["log2fc"], y, c=colors, s=6)
    plt.axhline(-np.log10(fdr_thr), ls="--", c="black", lw=0.8)
    plt.axvline(lfc_thr, ls="--", c="black", lw=0.8)
    plt.axvline(-lfc_thr, ls="--", c="black", lw=0.8)
    plt.xlabel("log2 fold change (tumeur - normal)")
    plt.ylabel("-log10(FDR)")
    plt.title("Volcano plot")
    plt.tight_layout()
    plt.savefig(out_dir / "volcano_plot.png", dpi=150)
    plt.close()


def main():
    a = parse_args()
    expr, meta, annot = load_data(a.matrix, a.metadata, a.annotation)
    validate_pairs(expr, meta)
    expr = to_log2(expr)
    res = paired_test(expr, meta)
    res = adjust_fdr(res, a.fdr, a.lfc)
    res = add_annotation(res, annot)

    out = Path(a.out_table)
    out.parent.mkdir(parents=True, exist_ok=True)
    res.to_csv(out, index=False, encoding="utf-8")
    make_volcano(res, a.out_figures, a.fdr, a.lfc)

    n_sig = int(res["significant"].sum())
    n_up = int((res["significant"] & (res["log2fc"] > 0)).sum())
    fig_path = Path(a.out_figures) / "volcano_plot.png"

    print("\n[INFO] Résumé de l'analyse différentielle :")
    print(f"[OK] Sondes analysées : {len(res):,}".replace(",", " "))
    print(
        f"[OK] Sondes significatives : {n_sig} "
        f"(plus actives : {n_up}, moins actives : {n_sig - n_up})"
    )
    print(f"\n[OK] Tableau généré : {out}")
    print(f"[OK] Figure générée : {fig_path}")
    print("\n[OK] Analyse terminée avec succès.")


if __name__ == "__main__":
    main()