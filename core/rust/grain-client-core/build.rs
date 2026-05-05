fn main() {
    if std::env::var_os("CARGO_FEATURE_BINDINGS").is_some() {
        uniffi_build::generate_scaffolding("src/grain_client_core.udl").unwrap();
    }
}
