package mobilecore

import (
	"encoding/json"
	"strings"
	"testing"
	"time"

	"github.com/syncthing/syncthing/lib/events"
)

func eventAt(t time.Time, typ events.EventType, data map[string]interface{}) events.Event {
	return events.Event{Time: t, Type: typ, Data: data}
}

func TestSafeActivityPathAcceptsRelativeRejectsUnsafe(t *testing.T) {
	cases := []struct {
		in   string
		ok   bool
		want string
	}{
		{"Notes/idea.md", true, "Notes/idea.md"},
		{"  a/b.md  ", true, "a/b.md"},
		{`a\b.md`, true, "a/b.md"},
		{"./Notes/x.md", true, "Notes/x.md"},
		{"", false, ""},
		{"   ", false, ""},
		{"/etc/passwd", false, ""},
		{"../escape.md", false, ""},
		{"Notes/../../escape.md", false, ""},
		{"C:/vault/note.md", false, ""},
	}
	for _, c := range cases {
		got, ok := safeActivityPath(c.in)
		if ok != c.ok || got != c.want {
			t.Fatalf("safeActivityPath(%q) = (%q, %v), want (%q, %v)", c.in, got, ok, c.want, c.ok)
		}
	}
}

func TestNormalizedActivityActionAndType(t *testing.T) {
	if got := normalizedActivityAction("  UPDATE  "); got != "updated" {
		t.Fatalf("action update = %q", got)
	}
	if got := normalizedActivityAction("deleted"); got != "deleted" {
		t.Fatalf("action deleted = %q", got)
	}
	if got := normalizedActivityAction("weird"); got != "changed" {
		t.Fatalf("action fallback = %q", got)
	}
	if got := normalizedActivityType("directory"); got != "directory" {
		t.Fatalf("type directory = %q", got)
	}
	if got := normalizedActivityType(""); got != "file" {
		t.Fatalf("type fallback = %q", got)
	}
}

func TestRecorderRecordsSanitizedNewestFirstAndDeduplicates(t *testing.T) {
	r := newActivityRecorder()
	base := time.Date(2026, 8, 1, 12, 0, 0, 0, time.UTC)
	r.record(eventAt(base, events.LocalChangeDetected, map[string]interface{}{
		"folder": "vault", "path": "Notes/a.md", "action": "update", "type": "file",
	}))
	r.record(eventAt(base.Add(time.Second), events.LocalChangeDetected, map[string]interface{}{
		"folder": "vault", "path": "Notes/a.md", "action": "update", "type": "file",
	}))
	r.record(eventAt(base.Add(2*time.Second), events.ItemFinished, map[string]interface{}{
		"folder": "vault", "item": "Notes/b.md", "action": "update", "type": "file",
	}))
	r.record(eventAt(base, events.LocalChangeDetected, map[string]interface{}{
		"folder": "vault", "path": "/absolute/leak.md", "action": "update", "type": "file",
	}))
	snap := r.snapshot("vault")
	if snap.SchemaVersion != 1 || snap.FolderID != "vault" {
		t.Fatalf("snapshot identity = %#v", snap)
	}
	if len(snap.Items) != 2 {
		t.Fatalf("items = %d, want 2 (dedup + reject absolute)", len(snap.Items))
	}
	if snap.Items[0].Path != "Notes/b.md" || snap.Items[0].Direction != "incoming" {
		t.Fatalf("newest first violated: %#v", snap.Items[0])
	}
	if snap.Items[1].Direction != "outgoing" || snap.Items[1].Result != "detected" {
		t.Fatalf("outgoing mapping wrong: %#v", snap.Items[1])
	}
}

func TestRecorderItemFinishedErrorBecomesFailed(t *testing.T) {
	r := newActivityRecorder()
	errMsg := "boom"
	r.record(eventAt(time.Now(), events.ItemFinished, map[string]interface{}{
		"folder": "vault", "item": "Notes/c.md", "action": "update", "type": "file",
		"error": &errMsg,
	}))
	items := r.snapshot("vault").Items
	if len(items) != 1 || items[0].Result != "failed" {
		t.Fatalf("expected failed result, got %#v", items)
	}
}

func TestRecorderIgnoresUnknownFolderAndBlankFolder(t *testing.T) {
	r := newActivityRecorder()
	r.record(eventAt(time.Now(), events.LocalChangeDetected, map[string]interface{}{
		"folder": "", "path": "Notes/a.md", "action": "update", "type": "file",
	}))
	r.record(eventAt(time.Now(), events.LocalChangeDetected, map[string]interface{}{
		"folder": "other", "path": "Notes/a.md", "action": "update", "type": "file",
	}))
	if got := r.snapshot("vault").Items; len(got) != 0 {
		t.Fatalf("expected no items for vault, got %d", len(got))
	}
}

func TestRecorderBoundsToMaximumItems(t *testing.T) {
	r := newActivityRecorder()
	now := time.Now()
	for i := 0; i < maximumRecentActivityItems+10; i++ {
		r.record(eventAt(now.Add(time.Duration(i)*time.Second), events.LocalChangeDetected, map[string]interface{}{
			"folder": "vault", "path": "n" + string(rune('a'+i%26)) + ".md",
			"action": "update", "type": "file",
		}))
	}
	items := r.snapshot("vault").Items
	if len(items) != maximumRecentActivityItems {
		t.Fatalf("items = %d, want %d", len(items), maximumRecentActivityItems)
	}
}

func TestRecentActivityJSONErrorPaths(t *testing.T) {
	e := &syncthingEngine{}
	if _, err := e.RecentActivityJSON(""); err == nil {
		t.Fatal("empty folder ID should error")
	}
	if _, err := e.RecentActivityJSON("vault"); err == nil {
		t.Fatal("not-running engine should error")
	}
}

func TestRecentActivityJSONContractOnConfiguredFolder(t *testing.T) {
	client, err := NewClient(t.TempDir())
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}
	peer, err := NewClient(t.TempDir())
	if err != nil {
		t.Fatalf("peer NewClient() error = %v", err)
	}
	vault := temporarySyncedFolder(t)
	if err := client.Start(); err != nil {
		t.Fatalf("Start() error = %v", err)
	}
	t.Cleanup(func() {
		if client.State() == StateRunning {
			_ = client.Stop()
		}
	})
	if err := client.ConfigurePeer(peer.DeviceID(), "Desktop", `["dynamic"]`); err != nil {
		t.Fatalf("ConfigurePeer() error = %v", err)
	}
	if err := client.ConfigureFolder("obsidian-vault", vault, "Notes", peer.DeviceID()); err != nil {
		t.Fatalf("ConfigureFolder() error = %v", err)
	}
	payload, err := client.RecentActivityJSON("obsidian-vault")
	if err != nil {
		t.Fatalf("RecentActivityJSON() error = %v", err)
	}
	var snap activitySnapshot
	if err := json.Unmarshal([]byte(payload), &snap); err != nil {
		t.Fatalf("RecentActivityJSON() invalid JSON: %v", err)
	}
	if snap.SchemaVersion != 1 || snap.FolderID != "obsidian-vault" {
		t.Fatalf("snapshot identity = %#v", snap)
	}
	if _, err := client.RecentActivityJSON("missing"); err == nil {
		t.Fatal("unconfigured folder should error")
	}
	if strings.Contains(payload, vault) {
		t.Fatalf("activity leaked absolute vault path: %s", payload)
	}
}
