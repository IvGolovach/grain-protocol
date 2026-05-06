use base64::engine::general_purpose::STANDARD;
use base64::Engine;
use clap::Parser;
use grain_issuer_kit::Issuer;
use serde_json::json;

#[derive(Debug, Parser)]
#[command(about = "Issue a reference signed Grain GR1 QR payload with public trust material")]
struct Args {
    /// Optional strict DAG-CBOR payload bytes as standard base64.
    #[arg(long)]
    payload_b64: Option<String>,

    /// Pretty-print JSON output.
    #[arg(long)]
    pretty: bool,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let issuer = Issuer::generate()?;

    let issued = match args.payload_b64 {
        Some(payload_b64) => {
            let payload = STANDARD.decode(payload_b64)?;
            issuer.issue_payload(&payload)?
        }
        None => issuer.issue_sample_serving_offer()?,
    };

    let output = json!({
        "qr_string": issued.qr_string,
        "trust_pub_b64": issued.trust_pub_b64,
        "issuer_kid_b64": issued.issuer_kid_b64,
        "cose_b64": issued.cose_b64
    });

    if args.pretty {
        println!("{}", serde_json::to_string_pretty(&output)?);
    } else {
        println!("{}", serde_json::to_string(&output)?);
    }

    Ok(())
}
