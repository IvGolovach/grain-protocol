#[path = "support/workflow_fixture.rs"]
mod workflow_fixture;

use grain_client_core::{
    client_lifecycle, device_add_key, device_revoke_key, device_set_active, identity_create_root,
    pairing_accept_envelope, pairing_create_envelope, pairing_preview_envelope,
    platform::{
        scan_accept_with_trust_provider, scan_preview_with_trust_provider, StaticTrustProvider,
    },
    scan_accept, scan_preview, sync_export_bundle, sync_import_bundle, ClientStore, DeviceStatus,
    IdentityStatus, MemoryClientStore, PairingStatus, ScanAcceptStatus, SyncStatus,
};
use workflow_fixture::{
    load_device_lifecycle_fixtures, load_pairing_fixtures, load_scan_accept_fixtures,
    load_scan_preview_fixtures, load_sync_bundle_fixtures, resolve_string_ref, CosePresence,
    Presence, StoreMutation, WorkflowExpect, WorkflowInput, WorkflowName,
};

#[test]
fn scan_preview_matches_client_workflow_fixtures() -> Result<(), String> {
    let fixtures = load_scan_preview_fixtures()?;
    assert!(
        !fixtures.is_empty(),
        "expected at least one scan_preview fixture"
    );

    for fixture in fixtures {
        assert_eq!(fixture.workflow, WorkflowName::ScanPreview);
        assert!(fixture.strict, "{} must be strict", fixture.fixture_id);
        assert_eq!(
            fixture.expect.store_mutation,
            Some(StoreMutation::None),
            "{} must not mutate client storage in scan_preview",
            fixture.fixture_id
        );
        assert!(
            !fixture.meta.desc.is_empty(),
            "{} must include meta.desc",
            fixture.fixture_id
        );

        require_exactly_one_diag_expectation(&fixture.expect, &fixture.fixture_id)?;

        let qr_string = fixture_qr_string(&fixture.input, &fixture.fixture_id)?;
        let preview = if let Some(trust_anchor_id) = fixture.input.trust_anchor_id.as_deref() {
            let provider = fixture_trust_provider(&fixture.input, &fixture.fixture_id)?;
            scan_preview_with_trust_provider(&qr_string, Some(trust_anchor_id), &provider)
        } else {
            let trust_pub_b64 = fixture_trust(&fixture.input, &fixture.fixture_id)?;
            scan_preview(&qr_string, trust_pub_b64.as_deref())
        };
        assert_eq!(
            preview.status,
            fixture.expect.status.as_preview_status(),
            "{} status mismatch",
            fixture.fixture_id
        );

        assert_diagnostics(&preview.diag, &fixture.expect, &fixture.fixture_id);

        match fixture
            .expect
            .cose_b64
            .as_ref()
            .expect("scan_preview fixture must assert cose_b64")
        {
            CosePresence::Present => assert!(
                preview.cose_b64.is_some(),
                "{} expected COSE bytes to be present",
                fixture.fixture_id
            ),
            CosePresence::Absent => assert!(
                preview.cose_b64.is_none(),
                "{} expected COSE bytes to be absent",
                fixture.fixture_id
            ),
        }
    }

    Ok(())
}

#[test]
fn scan_accept_matches_client_workflow_fixtures() -> Result<(), String> {
    let fixtures = load_scan_accept_fixtures()?;
    assert!(
        !fixtures.is_empty(),
        "expected at least one scan_accept fixture"
    );

    for fixture in fixtures {
        assert_eq!(fixture.workflow, WorkflowName::ScanAccept);
        assert!(fixture.strict, "{} must be strict", fixture.fixture_id);
        assert!(
            !fixture.meta.desc.is_empty(),
            "{} must include meta.desc",
            fixture.fixture_id
        );

        require_exactly_one_diag_expectation(&fixture.expect, &fixture.fixture_id)?;

        let qr_string = fixture_qr_string(&fixture.input, &fixture.fixture_id)?;
        let provider = if fixture.input.trust_anchor_id.is_some() {
            Some(fixture_trust_provider(&fixture.input, &fixture.fixture_id)?)
        } else {
            None
        };
        let trust_pub_b64 = if fixture.input.trust_anchor_id.is_some() {
            None
        } else {
            fixture_trust(&fixture.input, &fixture.fixture_id)?
        };

        let accept_attempts = fixture.input.accept_attempts.unwrap_or(1);
        assert!(
            accept_attempts > 0,
            "{} accept_attempts must be at least 1",
            fixture.fixture_id
        );

        let mut store = MemoryClientStore::new();
        let mut accepted = None;
        for _ in 0..accept_attempts {
            accepted = Some(
                if let (Some(trust_anchor_id), Some(provider)) =
                    (fixture.input.trust_anchor_id.as_deref(), provider.as_ref())
                {
                    scan_accept_with_trust_provider(
                        &mut store,
                        &qr_string,
                        Some(trust_anchor_id),
                        provider,
                    )
                } else {
                    scan_accept(&mut store, &qr_string, trust_pub_b64.as_deref())
                },
            );
        }
        let accepted = accepted.expect("accept_attempts is validated above");
        assert_eq!(
            accepted.status,
            fixture.expect.status.as_accept_status(),
            "{} status mismatch",
            fixture.fixture_id
        );

        assert_diagnostics(&accepted.diag, &fixture.expect, &fixture.fixture_id);

        match fixture
            .expect
            .cose_b64
            .as_ref()
            .expect("scan_accept fixture must assert cose_b64")
        {
            CosePresence::Present => assert!(
                accepted
                    .accepted
                    .as_ref()
                    .map(|record| !record.cose_b64.is_empty())
                    .unwrap_or(false),
                "{} expected accepted COSE bytes to be present",
                fixture.fixture_id
            ),
            CosePresence::Absent => assert!(
                accepted.accepted.is_none(),
                "{} expected accepted COSE bytes to be absent",
                fixture.fixture_id
            ),
        }

        match fixture
            .expect
            .store_mutation
            .as_ref()
            .expect("scan_accept fixture must assert store_mutation")
        {
            StoreMutation::AcceptedScanInserted => assert!(
                !store.list_accepted_scans().is_empty(),
                "{} expected an accepted scan to be persisted",
                fixture.fixture_id
            ),
            StoreMutation::None => assert!(
                store.list_accepted_scans().is_empty(),
                "{} expected no accepted scans to be persisted",
                fixture.fixture_id
            ),
        }

        if let Some(expected_count) = fixture.expect.accepted_record_count {
            assert_eq!(
                store.list_accepted_scans().len(),
                expected_count,
                "{} accepted record count mismatch",
                fixture.fixture_id
            );
        }
    }

    Ok(())
}

#[test]
fn device_lifecycle_matches_client_workflow_fixtures() -> Result<(), String> {
    let fixtures = load_device_lifecycle_fixtures()?;
    assert!(
        !fixtures.is_empty(),
        "expected at least one device_lifecycle fixture"
    );

    for fixture in fixtures {
        assert_eq!(fixture.workflow, WorkflowName::DeviceLifecycle);
        assert!(fixture.strict, "{} must be strict", fixture.fixture_id);
        require_exactly_one_diag_expectation(&fixture.expect, &fixture.fixture_id)?;

        let mut store = MemoryClientStore::new();
        let root = identity_create_root(
            &mut store,
            fixture.input.root_label.as_deref().unwrap_or("root"),
        );
        assert_eq!(root.status, IdentityStatus::Created);
        let added = device_add_key(
            &mut store,
            fixture.input.device_label.as_deref().unwrap_or("device"),
        );
        assert_eq!(added.status, DeviceStatus::Added);
        let device_ak = added
            .device_ak
            .as_deref()
            .ok_or_else(|| format!("{} missing device ak", fixture.fixture_id))?;
        let active = device_set_active(&mut store, device_ak);
        assert_eq!(active.status, DeviceStatus::Active);
        let revoked = device_revoke_key(&mut store, device_ak);
        assert_eq!(revoked.status, DeviceStatus::Revoked);

        let lifecycle = client_lifecycle(&store);
        assert_eq!(
            lifecycle.status,
            fixture.expect.status.as_lifecycle_status(),
            "{} lifecycle status mismatch",
            fixture.fixture_id
        );
        assert_diagnostics(&lifecycle.diag, &fixture.expect, &fixture.fixture_id);
        assert_presence(
            lifecycle.root_kid.as_deref(),
            &fixture.expect.root_kid,
            "root_kid",
            &fixture.fixture_id,
        );
        assert_presence(
            lifecycle.active_ak.as_deref(),
            &fixture.expect.active_ak,
            "active_ak",
            &fixture.fixture_id,
        );
        assert_presence(
            Some(device_ak),
            &fixture.expect.device_ak,
            "device_ak",
            &fixture.fixture_id,
        );
        assert_count(
            lifecycle.device_count,
            fixture.expect.device_count,
            "device_count",
            &fixture.fixture_id,
        );
        assert_count(
            lifecycle.revoked_count,
            fixture.expect.revoked_count,
            "revoked_count",
            &fixture.fixture_id,
        );
        assert_count(
            lifecycle.accepted_record_count,
            fixture
                .expect
                .accepted_record_count
                .map(|count| count as u64),
            "accepted_record_count",
            &fixture.fixture_id,
        );
        assert_count(
            lifecycle.lifecycle_event_count,
            fixture.expect.lifecycle_event_count,
            "lifecycle_event_count",
            &fixture.fixture_id,
        );
    }

    Ok(())
}

#[test]
fn pairing_matches_client_workflow_fixtures() -> Result<(), String> {
    let fixtures = load_pairing_fixtures()?;
    assert!(
        !fixtures.is_empty(),
        "expected at least one pairing fixture"
    );

    for fixture in fixtures {
        assert_eq!(fixture.workflow, WorkflowName::Pairing);
        assert!(fixture.strict, "{} must be strict", fixture.fixture_id);
        require_exactly_one_diag_expectation(&fixture.expect, &fixture.fixture_id)?;

        let mut source = MemoryClientStore::new();
        assert_eq!(
            identity_create_root(
                &mut source,
                fixture.input.root_label.as_deref().unwrap_or("root")
            )
            .status,
            IdentityStatus::Created
        );
        assert_eq!(
            device_add_key(
                &mut source,
                fixture.input.device_label.as_deref().unwrap_or("device")
            )
            .status,
            DeviceStatus::Added
        );

        let envelope = pairing_create_envelope(&source);
        assert_eq!(envelope.status, PairingStatus::Created);
        assert_presence(
            envelope.envelope_b64.as_deref(),
            &fixture.expect.envelope_b64,
            "envelope_b64",
            &fixture.fixture_id,
        );
        let envelope_b64 = envelope
            .envelope_b64
            .as_deref()
            .ok_or_else(|| format!("{} missing envelope", fixture.fixture_id))?;
        let preview = pairing_preview_envelope(envelope_b64);
        assert_eq!(preview.status, PairingStatus::Valid);

        let mut target = MemoryClientStore::new();
        let accept_attempts = fixture.input.accept_attempts.unwrap_or(1);
        assert!(
            accept_attempts > 0,
            "{} accept_attempts must be at least 1",
            fixture.fixture_id
        );
        let mut paired = None;
        for _ in 0..accept_attempts {
            paired = Some(pairing_accept_envelope(&mut target, envelope_b64));
        }
        let paired = paired.expect("accept_attempts is validated by fixture checker");
        assert_eq!(
            paired.status,
            fixture.expect.status.as_pairing_status(),
            "{} pairing status mismatch",
            fixture.fixture_id
        );
        assert_diagnostics(&paired.diag, &fixture.expect, &fixture.fixture_id);
        assert_presence(
            paired.root_kid.as_deref(),
            &fixture.expect.root_kid,
            "root_kid",
            &fixture.fixture_id,
        );
        assert_presence(
            paired.pairing_id.as_deref(),
            &fixture.expect.pairing_id,
            "pairing_id",
            &fixture.fixture_id,
        );
        assert_count(
            paired.device_count,
            fixture.expect.device_count,
            "device_count",
            &fixture.fixture_id,
        );
    }

    Ok(())
}

#[test]
fn sync_bundle_matches_client_workflow_fixtures() -> Result<(), String> {
    let fixtures = load_sync_bundle_fixtures()?;
    assert!(
        !fixtures.is_empty(),
        "expected at least one sync_bundle fixture"
    );

    for fixture in fixtures {
        assert_eq!(fixture.workflow, WorkflowName::SyncBundle);
        assert!(fixture.strict, "{} must be strict", fixture.fixture_id);
        require_exactly_one_diag_expectation(&fixture.expect, &fixture.fixture_id)?;

        let mut source = MemoryClientStore::new();
        assert_eq!(
            identity_create_root(
                &mut source,
                fixture.input.root_label.as_deref().unwrap_or("root")
            )
            .status,
            IdentityStatus::Created
        );
        assert_eq!(
            device_add_key(
                &mut source,
                fixture.input.device_label.as_deref().unwrap_or("device")
            )
            .status,
            DeviceStatus::Added
        );
        let qr_string = fixture_qr_string(&fixture.input, &fixture.fixture_id)?;
        let trust_pub_b64 = fixture_trust(&fixture.input, &fixture.fixture_id)?
            .ok_or_else(|| format!("{} missing trust material", fixture.fixture_id))?;
        let accepted = scan_accept(&mut source, &qr_string, Some(&trust_pub_b64));
        assert_eq!(accepted.status, ScanAcceptStatus::Accepted);
        assert!(accepted.diag.is_empty());

        let exported = sync_export_bundle(&source);
        assert_eq!(exported.status, SyncStatus::Exported);
        assert_presence(
            exported.bundle_b64.as_deref(),
            &fixture.expect.bundle_b64,
            "bundle_b64",
            &fixture.fixture_id,
        );
        let bundle_b64 = exported
            .bundle_b64
            .as_deref()
            .ok_or_else(|| format!("{} missing sync bundle", fixture.fixture_id))?;

        let mut target = MemoryClientStore::new();
        let import_attempts = fixture.input.import_attempts.unwrap_or(1);
        assert!(
            import_attempts > 0,
            "{} import_attempts must be at least 1",
            fixture.fixture_id
        );
        let mut imported = None;
        for _ in 0..import_attempts {
            imported = Some(sync_import_bundle(&mut target, bundle_b64));
        }
        let imported = imported.expect("import_attempts is validated by fixture checker");
        assert_eq!(
            imported.status,
            fixture.expect.status.as_sync_status(),
            "{} sync status mismatch",
            fixture.fixture_id
        );
        assert_diagnostics(&imported.diag, &fixture.expect, &fixture.fixture_id);
        assert_count(
            imported.accepted_record_count,
            fixture
                .expect
                .accepted_record_count
                .map(|count| count as u64),
            "accepted_record_count",
            &fixture.fixture_id,
        );
        assert_count(
            imported.device_count,
            fixture.expect.device_count,
            "device_count",
            &fixture.fixture_id,
        );
        assert_count(
            imported.lifecycle_event_count,
            fixture.expect.lifecycle_event_count,
            "lifecycle_event_count",
            &fixture.fixture_id,
        );
    }

    Ok(())
}

fn fixture_qr_string(input: &WorkflowInput, fixture_id: &str) -> Result<String, String> {
    let reference = input
        .qr_string_ref
        .as_deref()
        .ok_or_else(|| format!("{fixture_id} qr_string_ref is required"))?;
    resolve_string_ref(reference).map_err(|err| format!("{fixture_id} qr_string_ref: {err}"))
}

fn fixture_trust(input: &WorkflowInput, fixture_id: &str) -> Result<Option<String>, String> {
    match (
        input.trust_pub_b64_ref.as_deref(),
        input.trust_pub_b64.as_deref(),
    ) {
        (Some(_), Some(_)) => Err(format!(
            "{fixture_id} cannot provide both trust_pub_b64_ref and trust_pub_b64"
        )),
        (Some(reference), None) => {
            Ok(Some(resolve_string_ref(reference).map_err(|err| {
                format!("{fixture_id} trust_pub_b64_ref: {err}")
            })?))
        }
        (None, Some(inline)) => Ok(Some(inline.to_owned())),
        (None, None) => Ok(None),
    }
}

fn fixture_trust_provider(
    input: &WorkflowInput,
    fixture_id: &str,
) -> Result<StaticTrustProvider, String> {
    let Some(trust_anchor_id) = input.trust_anchor_id.as_deref() else {
        return Err(format!("{fixture_id} trust_anchor_id is required"));
    };
    let provider = if let Some(trust_pub_b64) = fixture_trust(input, fixture_id)? {
        StaticTrustProvider::new().with_anchor(trust_anchor_id, trust_pub_b64)
    } else {
        StaticTrustProvider::new()
    };
    Ok(provider)
}

fn require_exactly_one_diag_expectation(
    expect: &WorkflowExpect,
    fixture_id: &str,
) -> Result<(), String> {
    let diag_expectations =
        usize::from(expect.diag.is_some()) + usize::from(expect.diag_contains.is_some());
    if diag_expectations == 1 {
        Ok(())
    } else {
        Err(format!(
            "{fixture_id} must define exactly one diagnostic expectation"
        ))
    }
}

fn assert_diagnostics(actual: &[String], expect: &WorkflowExpect, fixture_id: &str) {
    if let Some(expected_diag) = expect.diag.as_ref() {
        assert_eq!(
            actual, expected_diag,
            "{fixture_id} exact diagnostics mismatch"
        );
    }
    if let Some(expected_diag) = expect.diag_contains.as_ref() {
        assert!(
            !expected_diag.is_empty(),
            "{fixture_id} diag_contains must not be empty; use diag: [] to assert empty diagnostics"
        );
        for code in expected_diag {
            assert!(
                actual.contains(code),
                "{fixture_id} expected diagnostic {code}, actual {actual:?}"
            );
        }
    }
}

fn assert_presence(
    actual: Option<&str>,
    expected: &Option<Presence>,
    field_name: &str,
    fixture_id: &str,
) {
    match expected {
        Some(Presence::Present) => assert!(
            actual.map(|value| !value.is_empty()).unwrap_or(false),
            "{fixture_id} expected {field_name} to be present"
        ),
        Some(Presence::Absent) => assert!(
            actual.is_none(),
            "{fixture_id} expected {field_name} to be absent"
        ),
        None => {}
    }
}

fn assert_count(actual: u64, expected: Option<u64>, field_name: &str, fixture_id: &str) {
    if let Some(expected) = expected {
        assert_eq!(actual, expected, "{fixture_id} {field_name} count mismatch");
    }
}
