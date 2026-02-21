use std::fs;
use std::path::PathBuf;

use clap::{Parser, Subcommand};
use grain_core::{execute_operation, OperationResult};
use serde::Deserialize;
use serde_json::{json, Value};

#[derive(Parser)]
#[command(name = "grain-runner")]
#[command(about = "Grain conformance runner")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    Run {
        #[arg(long)]
        strict: bool,
        #[arg(long)]
        vector: PathBuf,
    },
}

#[derive(Debug, Deserialize)]
struct VectorFile {
    vector_id: String,
    op: String,
    strict: bool,
    input: Value,
    expect: Expect,
}

#[derive(Debug, Deserialize)]
struct Expect {
    pass: bool,
    #[serde(default)]
    diag_contains: Vec<String>,
    #[serde(default)]
    out: Option<Value>,
    #[serde(default)]
    out_equals: Option<Value>,
}

fn main() {
    let cli = Cli::parse();
    let (output, exit_code) = match cli.command {
        Commands::Run { strict, vector } => run_vector(strict, vector),
    };

    println!(
        "{}",
        serde_json::to_string(&output).unwrap_or_else(|_| {
            "{\"vector_id\":\"unknown\",\"pass\":false,\"diag\":[\"GRAIN_ERR_SCHEMA\"],\"out\":{}}".to_string()
        })
    );

    std::process::exit(exit_code);
}

fn run_vector(strict_flag: bool, vector_path: PathBuf) -> (Value, i32) {
    let text = match fs::read_to_string(&vector_path) {
        Ok(t) => t,
        Err(_) => {
            let out = json!({
                "vector_id": "unknown",
                "pass": false,
                "diag": ["GRAIN_ERR_SCHEMA"],
                "out": {},
            });
            return (out, 1);
        }
    };

    let vector: VectorFile = match serde_json::from_str(&text) {
        Ok(v) => v,
        Err(_) => {
            let out = json!({
                "vector_id": "unknown",
                "pass": false,
                "diag": ["GRAIN_ERR_SCHEMA"],
                "out": {},
            });
            return (out, 1);
        }
    };

    let strict = strict_flag && vector.strict;
    let actual = execute_operation(&vector.op, &vector.input, strict);
    let vector_pass = evaluate_expectation(&vector.expect, &actual);

    let out = json!({
        "vector_id": vector.vector_id,
        "pass": vector_pass,
        "diag": actual.diag,
        "out": actual.out,
    });

    (out, if vector_pass { 0 } else { 1 })
}

fn evaluate_expectation(expect: &Expect, actual: &OperationResult) -> bool {
    if actual.accepted != expect.pass {
        return false;
    }

    let mut required_diags = expect.diag_contains.clone();

    if let Some(expected_out) = expect.out.as_ref().or(expect.out_equals.as_ref()) {
        if let Some(diags) = expected_out.get("diag_contains").and_then(Value::as_array) {
            for d in diags {
                if let Some(s) = d.as_str() {
                    required_diags.push(s.to_string());
                }
            }
        }

        if !value_subset_match_skip_diag(expected_out, &actual.out) {
            return false;
        }
    }

    let mut actual_diag = actual.diag.clone();
    if let Some(extra) = actual.out.get("diag_contains").and_then(Value::as_array) {
        for d in extra {
            if let Some(s) = d.as_str() {
                actual_diag.push(s.to_string());
            }
        }
    }

    for code in required_diags {
        if !actual_diag.iter().any(|d| d == &code) {
            return false;
        }
    }

    true
}

fn value_subset_match_skip_diag(expected: &Value, actual: &Value) -> bool {
    match (expected, actual) {
        (Value::Object(e), Value::Object(a)) => {
            for (k, ev) in e {
                if k == "diag_contains" {
                    continue;
                }
                let Some(av) = a.get(k) else {
                    return false;
                };
                if !value_subset_match_skip_diag(ev, av) {
                    return false;
                }
            }
            true
        }
        (Value::Array(e), Value::Array(a)) => e == a,
        _ => expected == actual,
    }
}
