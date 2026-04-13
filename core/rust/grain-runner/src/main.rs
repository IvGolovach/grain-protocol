use std::fs;
use std::path::PathBuf;

use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use clap::{Parser, Subcommand};
use grain_core::{execute_operation, OperationResult};
use serde::Deserialize;
use serde_json::{json, Value};

const JSON_SAFE_INTEGER_MAX_I64: i64 = 9_007_199_254_740_991;
const JSON_SAFE_INTEGER_MAX_U64: u64 = 9_007_199_254_740_991;

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
    Demo {
        #[arg(long)]
        strict: bool,
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
        Commands::Demo { strict } => run_demo(strict),
    };
    let output = normalize_runner_value(output);

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
    let actual = normalize_operation_result(execute_operation(&vector.op, &vector.input, strict));
    let vector_pass = evaluate_expectation(&vector.expect, &actual);

    let out = json!({
        "vector_id": vector.vector_id,
        "pass": vector_pass,
        "diag": actual.diag,
        "out": actual.out,
    });

    (out, if vector_pass { 0 } else { 1 })
}

fn run_demo(strict: bool) -> (Value, i32) {
    const QR_VECTOR: &str = include_str!("../../../../conformance/vectors/qr/POS-QR-001.json");
    const COSE_VECTOR: &str = include_str!("../../../../conformance/vectors/cose/POS-COSE-001.json");
    const LEDGER_VECTOR: &str = include_str!("../../../../conformance/vectors/ledger/POS-LED-001.json");

    if !strict {
        let out = json!({
            "demo_id": "quickstart-v0.1",
            "pass": false,
            "diag": ["GRAIN_ERR_SCHEMA"],
            "message": "demo requires --strict"
        });
        return (out, 1);
    }

    let qr_vector = match serde_json::from_str::<VectorFile>(QR_VECTOR) {
        Ok(v) => v,
        Err(_) => return demo_internal_error("DEMO_VECTOR_PARSE_QR"),
    };
    let cose_vector = match serde_json::from_str::<VectorFile>(COSE_VECTOR) {
        Ok(v) => v,
        Err(_) => return demo_internal_error("DEMO_VECTOR_PARSE_COSE"),
    };
    let ledger_vector = match serde_json::from_str::<VectorFile>(LEDGER_VECTOR) {
        Ok(v) => v,
        Err(_) => return demo_internal_error("DEMO_VECTOR_PARSE_LEDGER"),
    };

    let qr_actual = normalize_operation_result(execute_operation("qr_decode_gr1", &qr_vector.input, true));
    if !qr_actual.accepted {
        return demo_step_failed("qr_decode_gr1", &qr_actual);
    }
    let cose_b64 = match qr_actual.out.get("cose_b64").and_then(Value::as_str) {
        Some(v) => v.to_string(),
        None => return demo_internal_error("DEMO_QR_OUTPUT_SCHEMA"),
    };
    let cose_bytes_len = match STANDARD.decode(&cose_b64) {
        Ok(v) => v.len(),
        Err(_) => return demo_internal_error("DEMO_QR_OUTPUT_BASE64"),
    };

    let mut cose_input = cose_vector.input.clone();
    let Some(cose_obj) = cose_input.as_object_mut() else {
        return demo_internal_error("DEMO_COSE_INPUT_SCHEMA");
    };
    cose_obj.insert("cose_b64".to_string(), Value::String(cose_b64));

    let cose_actual = normalize_operation_result(execute_operation("cose_verify", &cose_input, true));
    if !cose_actual.accepted {
        return demo_step_failed("cose_verify", &cose_actual);
    }

    let mut ledger_input = ledger_vector.input.clone();
    let append_event = json!({
        "ak": "dev1",
        "seq": 3,
        "t": "IntakeEvent",
        "payload_cid": "cid-intake-demo-3",
        "body": {
            "mean": { "kcal": 60 },
            "var": { "kcal": 1 }
        }
    });

    let Some(ledger_obj) = ledger_input.as_object_mut() else {
        return demo_internal_error("DEMO_LEDGER_INPUT_SCHEMA");
    };
    let Some(events) = ledger_obj.get_mut("events").and_then(Value::as_array_mut) else {
        return demo_internal_error("DEMO_LEDGER_EVENTS_SCHEMA");
    };
    events.push(append_event.clone());

    let ledger_actual = normalize_operation_result(execute_operation("ledger_reduce", &ledger_input, true));
    if !ledger_actual.accepted {
        return demo_step_failed("ledger_reduce", &ledger_actual);
    }

    let sum_mean = match ledger_actual.out.get("sum_mean") {
        Some(v) => v.clone(),
        None => return demo_internal_error("DEMO_LEDGER_SUM_MEAN_MISSING"),
    };
    let sum_var = match ledger_actual.out.get("sum_var") {
        Some(v) => v.clone(),
        None => return demo_internal_error("DEMO_LEDGER_SUM_VAR_MISSING"),
    };

    let out = json!({
        "demo_id": "quickstart-v0.1",
        "pass": true,
        "strict": true,
        "source_vectors": ["POS-QR-001", "POS-COSE-001", "POS-LED-001"],
        "steps": {
            "qr_decode_gr1": {
                "pass": true,
                "diag": qr_actual.diag,
                "cose_bytes_len": cose_bytes_len
            },
            "cose_verify": {
                "pass": true,
                "diag": cose_actual.diag
            },
            "append_intake_event": {
                "pass": true,
                "event": append_event
            },
            "ledger_reduce": {
                "pass": true,
                "diag": ledger_actual.diag,
                "out": ledger_actual.out
            }
        },
        "result": {
            "sum_mean": sum_mean,
            "sum_var": sum_var
        }
    });

    (out, 0)
}

fn demo_step_failed(step: &str, actual: &OperationResult) -> (Value, i32) {
    let out = json!({
        "demo_id": "quickstart-v0.1",
        "pass": false,
        "failed_step": step,
        "diag": actual.diag,
        "out": actual.out
    });
    (out, 1)
}

fn demo_internal_error(code: &str) -> (Value, i32) {
    let out = json!({
        "demo_id": "quickstart-v0.1",
        "pass": false,
        "diag": [code]
    });
    (out, 1)
}

fn normalize_operation_result(actual: OperationResult) -> OperationResult {
    OperationResult {
        accepted: actual.accepted,
        diag: actual.diag,
        out: normalize_runner_value(actual.out),
    }
}

fn normalize_runner_value(value: Value) -> Value {
    match value {
        Value::Array(items) => Value::Array(items.into_iter().map(normalize_runner_value).collect()),
        Value::Object(entries) => Value::Object(
            entries
                .into_iter()
                .map(|(key, item)| (key, normalize_runner_value(item)))
                .collect(),
        ),
        Value::Number(number) => normalize_runner_number(number),
        other => other,
    }
}

fn normalize_runner_number(number: serde_json::Number) -> Value {
    if let Some(value) = number.as_i64() {
        if !(-JSON_SAFE_INTEGER_MAX_I64..=JSON_SAFE_INTEGER_MAX_I64).contains(&value) {
            return Value::String(value.to_string());
        }
        return Value::Number(number);
    }

    if let Some(value) = number.as_u64() {
        if value > JSON_SAFE_INTEGER_MAX_U64 {
            return Value::String(value.to_string());
        }
        return Value::Number(number);
    }

    Value::Number(number)
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_unsafe_json_integers_to_decimal_strings() {
        let normalized = normalize_runner_value(json!({
            "safe": 42,
            "unsafe_pos": 9_007_199_254_740_993i64,
            "unsafe_neg": -9_007_199_254_740_993i64,
            "nested": {
                "u64_like": 9_007_199_254_740_992u64
            }
        }));

        assert_eq!(normalized["safe"], json!(42));
        assert_eq!(normalized["unsafe_pos"], json!("9007199254740993"));
        assert_eq!(normalized["unsafe_neg"], json!("-9007199254740993"));
        assert_eq!(normalized["nested"]["u64_like"], json!("9007199254740992"));
    }

    #[test]
    fn normalized_outputs_match_string_expectations() {
        let expected = json!({
            "sum_mean": { "kcal": "9007199254740993" },
            "sum_var": { "kcal": 0 }
        });
        let actual = normalize_runner_value(json!({
            "sum_mean": { "kcal": 9_007_199_254_740_993i64 },
            "sum_var": { "kcal": 0 }
        }));

        assert!(value_subset_match_skip_diag(&expected, &actual));
    }
}
