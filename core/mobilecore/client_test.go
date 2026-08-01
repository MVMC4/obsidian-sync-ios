package mobilecore

import (
	"encoding/json"
	"errors"
	"sync"
	"testing"
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
