#!/usr/bin/env python3
"""Build the pinned MealMark Food Graph artifact from Epicure model repos.

This script is an update tool, not a runtime dependency. Production code reads
the generated JSON artifact from disk and never calls Hugging Face.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path
from typing import Any


PINNED_MODELS = {
    "cooc": {
        "repo": "Kaikaku/epicure-cooc",
        "revision": "03edd311adde6e39a2eb6f9f3fa78f7396be6b53",
    },
    "core": {
        "repo": "Kaikaku/epicure-core",
        "revision": "d31ebb5af8e92bbaf5cb67381d5006d4ea8368b7",
    },
    "chem": {
        "repo": "Kaikaku/epicure-chem",
        "revision": "2461ef3fbafab36d2b1111187a3df98721146861",
    },
}

DEFAULT_ALIASES = {
    "arborio rice": "rice",
    "basmati": "basmati_rice",
    "blue cheese": "blue_cheese",
    "bell pepper": "bell_pepper",
    "black bean": "black_bean",
    "cheddar cheese": "cheddar_cheese",
    "dumpling wrapper": "dumpling_wrapper",
    "greek yogurt": "yogurt",
    "hojiblanca olive": "olive",
    "mozzarella cheese": "mozzarella_cheese",
    "olive oil": "olive_oil",
    "oatmeal": "oat",
    "parmesan cheese": "parmesan_cheese",
    "pita bread": "pita_bread",
    "pizza dough": "dough",
    "ramen": "ramen_noodle",
    "ramen noodle": "ramen_noodle",
    "romaine lettuce": "lettuce",
    "sesame seed": "sesame_seed",
    "soft egg": "egg",
    "sourdough": "bread",
    "sourdough bread": "bread",
    "soy sauce": "soy_sauce",
}

AMBIGUOUS_ALIASES = {
    "stock": ["vegetable_stock", "chicken_broth", "beef_broth", "fish_stock"],
    "broth": ["chicken_broth", "beef_broth", "vegetable_stock"],
    "cheese": ["cheese", "cheddar_cheese", "mozzarella_cheese", "parmesan_cheese"],
    "oil": ["oil", "olive_oil", "sesame_oil", "vegetable_oil"],
}


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def load_model(repo: str, revision: str):
    try:
        from huggingface_hub import hf_hub_download
    except ImportError as exc:
        raise SystemExit("Install update-only dependency: pip install huggingface_hub safetensors numpy") from exc

    epicure_py = hf_hub_download("Kaikaku/epicure-core", "epicure.py", revision=PINNED_MODELS["core"]["revision"])
    sys.path.insert(0, os.path.dirname(epicure_py))
    from epicure import Epicure  # type: ignore

    return Epicure.from_pretrained(repo, revision=revision)


def top_neighbors(model: Any, ingredient: str, limit: int) -> list[dict[str, Any]]:
    return [
        {"name": name, "score": round(float(score), 6)}
        for name, score in model.neighbors(ingredient, k=limit)
    ]


def build(out_dir: Path, neighbor_limit: int) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)

    models = {
        key: load_model(spec["repo"], spec["revision"])
        for key, spec in PINNED_MODELS.items()
    }
    vocab = sorted(models["core"].vocab.keys())
    neighbors = {
        model_key: {
            ingredient: top_neighbors(model, ingredient, neighbor_limit)
            for ingredient in vocab
        }
        for model_key, model in models.items()
    }

    write_json(out_dir / "vocabulary.json", vocab)
    write_json(
        out_dir / "aliases.json",
        {
            "aliases": DEFAULT_ALIASES,
            "ambiguous_aliases": AMBIGUOUS_ALIASES,
        },
    )
    for model_key, model_neighbors in neighbors.items():
        write_json(out_dir / f"neighbors-{model_key}.json", model_neighbors)

    manifest = {
        "schema": "mealmark.food_graph.artifact.v1",
        "artifact_id": "mealmark-food-graph-v0.1",
        "created_by": "tools/food_graph/build_mealmark_food_graph.py",
        "source": {
            "name": "Epicure ingredient embeddings",
            "paper": "https://arxiv.org/abs/2605.22391",
            "models": PINNED_MODELS,
            "license": "CC BY 4.0",
        },
        "runtime_policy": {
            "no_network_required": True,
            "advisory_only": True,
            "may_change_kcal": False,
            "may_change_record_trust": False,
            "may_change_nutrition_confidence": False,
            "raw_photo_persistence": "forbidden",
            "raw_vector_persistence": "forbidden",
        },
        "vocabulary_count": len(vocab),
        "neighbor_limit": neighbor_limit,
        "files": {},
    }
    write_json(out_dir / "manifest.json", manifest)

    checksums = {
        path.name: {
            "sha256": sha256_file(path),
            "bytes": path.stat().st_size,
        }
        for path in sorted(out_dir.glob("*.json"))
        if path.name != "manifest.json"
    }
    manifest["files"] = checksums
    write_json(out_dir / "manifest.json", manifest)

    (out_dir / "LICENSES.md").write_text(
        "# MealMark Food Graph v0.1 Licenses\n\n"
        "This artifact is derived from the Epicure ingredient embedding model family:\n\n"
        "- Paper: https://arxiv.org/abs/2605.22391\n"
        "- Models: Kaikaku/epicure-cooc, Kaikaku/epicure-core, Kaikaku/epicure-chem\n"
        "- Authors: Jakub Radzikowski and Josef Chen\n"
        "- Released artifact license: CC BY 4.0\n\n"
        "The generated MealMark artifact is advisory-only. It is not a nutrition database, "
        "medical recommendation system, allergen engine, trust verifier, or calorie source.\n\n"
        "Production runtime must read the committed artifact locally and must not call "
        "Hugging Face or the Epicure demo Space.\n",
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--out",
        default="core/ts/grain-sdk-ai/food-graph-artifacts/mealmark-food-graph-v0.1",
        help="Output artifact directory.",
    )
    parser.add_argument("--neighbor-limit", type=int, default=16)
    args = parser.parse_args()
    if args.neighbor_limit < 1 or args.neighbor_limit > 64:
        raise SystemExit("--neighbor-limit must be between 1 and 64")
    build(Path(args.out), args.neighbor_limit)


if __name__ == "__main__":
    main()
