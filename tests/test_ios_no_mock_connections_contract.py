from pathlib import Path


SWIFT_ROOT = Path("byollm-assistantOS/MonolithChat")


def test_ios_does_not_ship_fabricated_connected_accounts():
    production_source = "\n".join(
        path.read_text(encoding="utf-8") for path in SWIFT_ROOT.glob("*.swift")
    )

    for fabricated_identity in (
        "monolith.slack.com",
        "@monolith",
        "Monolith HQ",
        "ops@monolith.ai",
    ):
        assert fabricated_identity not in production_source


def test_connections_ui_starts_github_authorization_in_client():
    source = (SWIFT_ROOT / "ConnectionsView.swift").read_text(encoding="utf-8")

    assert "Sign in from this device" in source
    assert "store.connectGitHub()" in source
    assert "server-managed" not in source
    assert "toggleConnection" not in source


def test_ios_never_accepts_a_raw_github_token():
    production_source = "\n".join(
        path.read_text(encoding="utf-8")
        for path in Path("byollm-assistantOS").rglob("*.swift")
    )

    assert "GITHUB_TOKEN" not in production_source
    assert "GH_TOKEN" not in production_source
    assert "access_token" not in production_source


def test_chat_has_no_canned_no_server_generation_fallback():
    source = (SWIFT_ROOT / "AppStore.swift").read_text(encoding="utf-8")

    assert "demoStream(chatId:" not in source
    assert "Fall back to a canned demo stream" not in source
