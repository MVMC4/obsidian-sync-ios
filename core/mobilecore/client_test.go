package mobilecore

import (
	"encoding/json"
	"errors"
	"slices"
	"sync"
	"testing"

	"github.com/syncthing/syncthing/lib/protocol"
)

type fakeEngine struct {
	mu         sync.Mutex
	deviceID   string
	startErr   error
	stopErr    error
	startCalls int
	stopCalls  int
}

func (f *fakeEngine) Start() error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.startCalls++
	return f.startErr
}

func (f *fakeEngine) Stop() error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.stopCalls++
	return f.stopErr
}

func (f *fakeEngine) DeviceID() string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.deviceID
}

func TestClientStartsAndStopsIdempotently(t *testing.T) {
	eng := &fakeEngine{deviceID: "DEVICE-ID"}
	client := newClient(eng)

	if got := client.State(); got != StateIdle {
		t.Fatalf("initial state = %q, want %q", got, StateIdle)
	}
	if err := client.Start(); err != nil {
		t.Fatalf("Start() error = %v", err)
	}
	if err := client.Start(); err != nil {
		t.Fatalf("second Start() error = %v", err)
	}
	if got := client.State(); got != StateRunning {
		t.Fatalf("running state = %q, want %q", got, StateRunning)
	}
	if err := client.Stop(); err != nil {
		t.Fatalf("Stop() error = %v", err)
	}
	if err := client.Stop(); err != nil {
		t.Fatalf("second Stop() error = %v", err)
	}

	if eng.startCalls != 1 {
		t.Fatalf("engine Start() calls = %d, want 1", eng.startCalls)
	}
	if eng.stopCalls != 1 {
		t.Fatalf("engine Stop() calls = %d, want 1", eng.stopCalls)
	}
	if got := client.State(); got != StateStopped {
		t.Fatalf("stopped state = %q, want %q", got, StateStopped)
	}
}

func TestClientCannotRestartAStoppedOneShotEngine(t *testing.T) {
	client := newClient(&fakeEngine{})

	if err := client.Start(); err != nil {
		t.Fatalf("Start() error = %v", err)
	}
	if err := client.Stop(); err != nil {
		t.Fatalf("Stop() error = %v", err)
	}
	if err := client.Start(); !errors.Is(err, errTerminalState) {
		t.Fatalf("restart error = %v, want %v", err, errTerminalState)
	}
}

func TestClientRecordsStartFailure(t *testing.T) {
	startErr := errors.New("certificate unavailable")
	client := newClient(&fakeEngine{startErr: startErr})

	if err := client.Start(); !errors.Is(err, startErr) {
		t.Fatalf("Start() error = %v, want wrapped %v", err, startErr)
	}
	if got := client.State(); got != StateFailed {
		t.Fatalf("failed state = %q, want %q", got, StateFailed)
	}
	if got := client.LastError(); got != startErr.Error() {
		t.Fatalf("LastError() = %q, want %q", got, startErr.Error())
	}
}

func TestClientWithoutEngineFailsCleanly(t *testing.T) {
	client := newClient(nil)

	if err := client.Start(); !errors.Is(err, errNoEngine) {
		t.Fatalf("Start() error = %v, want %v", err, errNoEngine)
	}
	if got := client.State(); got != StateFailed {
		t.Fatalf("state = %q, want %q", got, StateFailed)
	}
}

func TestStatusJSONUsesVersionedPrimitiveContract(t *testing.T) {
	client := newClient(&fakeEngine{deviceID: "DEVICE-ID"})

	var got statusSnapshot
	if err := json.Unmarshal([]byte(client.StatusJSON()), &got); err != nil {
		t.Fatalf("StatusJSON() is invalid JSON: %v", err)
	}
	if got.SchemaVersion != 1 {
		t.Fatalf("schemaVersion = %d, want 1", got.SchemaVersion)
	}
	if got.State != StateIdle {
		t.Fatalf("state = %q, want %q", got.State, StateIdle)
	}
	if got.DeviceID != "DEVICE-ID" {
		t.Fatalf("deviceID = %q, want DEVICE-ID", got.DeviceID)
	}
}

func TestNewClientPersistsSyncthingIdentity(t *testing.T) {
	statePath := t.TempDir()

	first, err := NewClient(statePath)
	if err != nil {
		t.Fatalf("first NewClient() error = %v", err)
	}
	second, err := NewClient(statePath)
	if err != nil {
		t.Fatalf("second NewClient() error = %v", err)
	}

	if first.DeviceID() == "" {
		t.Fatal("first DeviceID() is empty")
	}
	if second.DeviceID() != first.DeviceID() {
		t.Fatalf("persisted DeviceID() = %q, want %q", second.DeviceID(), first.DeviceID())
	}
}

func TestRealSyncthingEngineStartsAndStops(t *testing.T) {
	client, err := NewClient(t.TempDir())
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}

	if err := client.Start(); err != nil {
		t.Fatalf("Start() error = %v", err)
	}
	if got := client.State(); got != StateRunning {
		t.Fatalf("running state = %q, want %q", got, StateRunning)
	}
	eng := client.engine.(*syncthingEngine)
	options := eng.config.Options()
	if !slices.Equal(options.RawListenAddresses, []string{"tcp://:22000"}) {
		t.Fatalf("listen addresses = %v, want TCP-only", options.RawListenAddresses)
	}
	if options.NATEnabled {
		t.Fatal("NAT traversal is enabled, want disabled while QUIC/STUN is excluded")
	}
	if err := client.Stop(); err != nil {
		t.Fatalf("Stop() error = %v", err)
	}
	if got := client.State(); got != StateStopped {
		t.Fatalf("stopped state = %q, want %q", got, StateStopped)
	}
}

func TestRealEngineConfiguresPeerFolderAndScan(t *testing.T) {
	client, err := NewClient(t.TempDir())
	if err != nil {
		t.Fatalf("NewClient() error = %v", err)
	}
	peer, err := NewClient(t.TempDir())
	if err != nil {
		t.Fatalf("peer NewClient() error = %v", err)
	}
	vaultPath := t.TempDir()

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
	if err := client.ConfigureFolder("obsidian-vault", vaultPath, "Notes", peer.DeviceID()); err != nil {
		t.Fatalf("ConfigureFolder() error = %v", err)
	}
	if err := client.Scan("obsidian-vault"); err != nil {
		t.Fatalf("Scan() error = %v", err)
	}

	eng := client.engine.(*syncthingEngine)
	peerID, _ := protocol.DeviceIDFromString(peer.DeviceID())
	if configuredPeer, ok := eng.config.Device(peerID); !ok || configuredPeer.Name != "Desktop" {
		t.Fatalf("configured peer = %#v, present = %v", configuredPeer, ok)
	}
	folder, ok := eng.config.Folder("obsidian-vault")
	if !ok {
		t.Fatal("configured folder is missing")
	}
	if folder.Path != vaultPath {
		t.Fatalf("folder path = %q, want %q", folder.Path, vaultPath)
	}
	if folder.FSWatcherEnabled {
		t.Fatal("folder watcher is enabled, want manual foreground scans")
	}
}

func TestParseAddresses(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    []string
		wantErr bool
	}{
		{name: "empty uses discovery", want: []string{"dynamic"}},
		{name: "empty array uses discovery", input: `[]`, want: []string{"dynamic"}},
		{name: "explicit", input: `["tcp://192.0.2.1:22000"]`, want: []string{"tcp://192.0.2.1:22000"}},
		{name: "invalid JSON", input: `[`, wantErr: true},
		{name: "blank address", input: `[""]`, wantErr: true},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, err := parseAddresses(test.input)
			if (err != nil) != test.wantErr {
				t.Fatalf("parseAddresses() error = %v, wantErr = %v", err, test.wantErr)
			}
			if !test.wantErr && !slices.Equal(got, test.want) {
				t.Fatalf("parseAddresses() = %v, want %v", got, test.want)
			}
		})
	}
}
