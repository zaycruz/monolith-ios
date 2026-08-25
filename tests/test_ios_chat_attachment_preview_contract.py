from pathlib import Path


def test_ios_composer_has_attachment_preview_and_remove_action():
    """
    Regression guard: the chat composer should render inline attachment previews
    (thumbnail tiles with an X remove button) when attachments are staged.
    """
    swift = Path("byollm-assistantOS/MonolithChat/ComposerView.swift").read_text(encoding="utf-8")
    assert "if let attachment = store.attach" in swift
    assert "store.clearAttach()" in swift
    assert 'accessibilityLabel("Remove \\(attachment)")' in swift
