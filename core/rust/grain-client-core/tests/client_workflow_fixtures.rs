#[path = "support/workflow_fixture.rs"]
mod workflow_fixture;

use grain_client_core::{scan_accept, scan_preview, ClientStore, MemoryClientStore};
use workflow_fixture::{
    load_scan_accept_fixtures, load_scan_preview_fixtures, resolve_string_ref, CosePresence,
    StoreMutation, WorkflowName,
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
            StoreMutation::None,
            "{} must not mutate client storage in scan_preview",
            fixture.fixture_id
        );
        assert!(
            !fixture.meta.desc.is_empty(),
            "{} must include meta.desc",
            fixture.fixture_id
        );

        let diag_expectations = usize::from(fixture.expect.diag.is_some())
            + usize::from(fixture.expect.diag_contains.is_some());
        assert_eq!(
            diag_expectations, 1,
            "{} must define exactly one diagnostic expectation",
            fixture.fixture_id
        );

        let qr_string = resolve_string_ref(&fixture.input.qr_string_ref)
            .map_err(|err| format!("{} qr_string_ref: {err}", fixture.fixture_id))?;
        let trust_pub_b64 = match (
            fixture.input.trust_pub_b64_ref.as_deref(),
            fixture.input.trust_pub_b64.as_deref(),
        ) {
            (Some(_), Some(_)) => {
                return Err(format!(
                    "{} cannot provide both trust_pub_b64_ref and trust_pub_b64",
                    fixture.fixture_id
                ))
            }
            (Some(reference), None) => Some(
                resolve_string_ref(reference)
                    .map_err(|err| format!("{} trust_pub_b64_ref: {err}", fixture.fixture_id))?,
            ),
            (None, Some(inline)) => Some(inline.to_owned()),
            (None, None) => None,
        };

        let preview = scan_preview(&qr_string, trust_pub_b64.as_deref());
        assert_eq!(
            preview.status,
            fixture.expect.status.as_preview_status(),
            "{} status mismatch",
            fixture.fixture_id
        );

        if let Some(expected_diag) = fixture.expect.diag.as_ref() {
            assert_eq!(
                &preview.diag, expected_diag,
                "{} exact diagnostics mismatch",
                fixture.fixture_id
            );
        }
        if let Some(expected_diag) = fixture.expect.diag_contains.as_ref() {
            assert!(
                !expected_diag.is_empty(),
                "{} diag_contains must not be empty; use diag: [] to assert empty diagnostics",
                fixture.fixture_id
            );
            for code in expected_diag {
                assert!(
                    preview.diag.contains(code),
                    "{} expected diagnostic {code}, actual {:?}",
                    fixture.fixture_id,
                    preview.diag
                );
            }
        }

        match fixture.expect.cose_b64 {
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

        let diag_expectations = usize::from(fixture.expect.diag.is_some())
            + usize::from(fixture.expect.diag_contains.is_some());
        assert_eq!(
            diag_expectations, 1,
            "{} must define exactly one diagnostic expectation",
            fixture.fixture_id
        );

        let qr_string = resolve_string_ref(&fixture.input.qr_string_ref)
            .map_err(|err| format!("{} qr_string_ref: {err}", fixture.fixture_id))?;
        let trust_pub_b64 = match (
            fixture.input.trust_pub_b64_ref.as_deref(),
            fixture.input.trust_pub_b64.as_deref(),
        ) {
            (Some(_), Some(_)) => {
                return Err(format!(
                    "{} cannot provide both trust_pub_b64_ref and trust_pub_b64",
                    fixture.fixture_id
                ))
            }
            (Some(reference), None) => Some(
                resolve_string_ref(reference)
                    .map_err(|err| format!("{} trust_pub_b64_ref: {err}", fixture.fixture_id))?,
            ),
            (None, Some(inline)) => Some(inline.to_owned()),
            (None, None) => None,
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
            accepted = Some(scan_accept(
                &mut store,
                &qr_string,
                trust_pub_b64.as_deref(),
            ));
        }
        let accepted = accepted.expect("accept_attempts is validated above");
        assert_eq!(
            accepted.status,
            fixture.expect.status.as_accept_status(),
            "{} status mismatch",
            fixture.fixture_id
        );

        if let Some(expected_diag) = fixture.expect.diag.as_ref() {
            assert_eq!(
                &accepted.diag, expected_diag,
                "{} exact diagnostics mismatch",
                fixture.fixture_id
            );
        }
        if let Some(expected_diag) = fixture.expect.diag_contains.as_ref() {
            assert!(
                !expected_diag.is_empty(),
                "{} diag_contains must not be empty; use diag: [] to assert empty diagnostics",
                fixture.fixture_id
            );
            for code in expected_diag {
                assert!(
                    accepted.diag.contains(code),
                    "{} expected diagnostic {code}, actual {:?}",
                    fixture.fixture_id,
                    accepted.diag
                );
            }
        }

        match fixture.expect.cose_b64 {
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

        match fixture.expect.store_mutation {
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
