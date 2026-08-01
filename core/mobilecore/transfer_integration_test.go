package mobilecore

import (
	"bytes"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"sync"
	"testing"
	"time"
)

const integrationFolderID = "integration-vault"

func TestBidirectionalTransferBetweenIndependentProcesses(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("two-process listener test is verified by the Ubuntu CI runner")
	}
	if testing.Short() {
		t.Skip("skipping real protocol transfer in short mode")
	}

	primaryState := t.TempDir()
	peerState := t.TempDir()
	primaryVault := t.TempDir()
	peerVault := t.TempDir()
	primaryListen := reserveTCPAddress(t)
	peerListen := reserveTCPAddress(t)

	primary, err := newIntegrationClient(primaryState, primaryListen)
	if err != nil {
		t.Fatalf("create primary client: %v", err)
	}
	peerIdentity, err := newIntegrationClient(peerState, peerListen)
	if err != nil {
		t.Fatalf("create peer identity: %v", err)
	}

	if err := primary.Start(); err != nil {
		t.Fatalf("start primary: %v", err)
	}
	defer func() {
		if primary.State() == StateRunning {
			if err := primary.Stop(); err != nil {
				t.Errorf("stop primary: %v", err)
			}
		}
	}()

	if err := primary.ConfigurePeer(
		peerIdentity.DeviceID(),
		"integration peer",
		fmt.Sprintf(`[%q]`, peerListen),
	); err != nil {
		t.Fatalf("configure primary peer: %v", err)
	}
	if err := primary.ConfigureFolder(
		integrationFolderID,
		primaryVault,
		"Integration vault",
		peerIdentity.DeviceID(),
	); err != nil {
		t.Fatalf("configure primary folder: %v", err)
	}

	readyFile := filepath.Join(t.TempDir(), "peer-ready")
	stopFile := filepath.Join(filepath.Dir(readyFile), "peer-stop")
	helper := startPeerHelper(t, peerHelperEnvironment{
		StatePath:      peerState,
		VaultPath:      peerVault,
		ListenAddress:  peerListen,
		RemoteDeviceID: primary.DeviceID(),
		RemoteAddress:  primaryListen,
		ReadyFile:      readyFile,
		StopFile:       stopFile,
	})
	defer helper.stop(t, stopFile)

	waitForPath(t, readyFile, helper, 20*time.Second)

	const outboundContent = "created by the mobile-core integration node\n"
	outboundPath := filepath.Join(primaryVault, "from-ipad.md")
	if err := os.WriteFile(outboundPath, []byte(outboundContent), 0o600); err != nil {
		t.Fatalf("write outbound note: %v", err)
	}
	if err := primary.Scan(integrationFolderID); err != nil {
		t.Fatalf("scan outbound note: %v", err)
	}

	waitForContent(
		t,
		filepath.Join(peerVault, "from-ipad.md"),
		outboundContent,
		helper,
		nil,
		45*time.Second,
	)

	const inboundContent = "created by the independent desktop peer\n"
	waitForContent(
		t,
		filepath.Join(primaryVault, "from-desktop.md"),
		inboundContent,
		helper,
		func() { _ = primary.Scan(integrationFolderID) },
		45*time.Second,
	)
}

func TestSyncthingPeerHelperProcess(t *testing.T) {
	if os.Getenv("OBS_SYNC_HELPER") != "1" {
		return
	}

	client, err := newIntegrationClient(
		os.Getenv("OBS_SYNC_STATE_PATH"),
		os.Getenv("OBS_SYNC_LISTEN_ADDRESS"),
	)
	if err != nil {
		t.Fatalf("create helper client: %v", err)
	}
	if err := client.Start(); err != nil {
		t.Fatalf("start helper client: %v", err)
	}
	defer func() {
		if client.State() == StateRunning {
			_ = client.Stop()
		}
	}()

	remoteDeviceID := os.Getenv("OBS_SYNC_REMOTE_DEVICE_ID")
	remoteAddress := os.Getenv("OBS_SYNC_REMOTE_ADDRESS")
	vaultPath := os.Getenv("OBS_SYNC_VAULT_PATH")
	if err := client.ConfigurePeer(
		remoteDeviceID,
		"integration primary",
		fmt.Sprintf(`[%q]`, remoteAddress),
	); err != nil {
		t.Fatalf("configure helper peer: %v", err)
	}
	if err := client.ConfigureFolder(
		integrationFolderID,
		vaultPath,
		"Integration vault",
		remoteDeviceID,
	); err != nil {
		t.Fatalf("configure helper folder: %v", err)
	}
	if err := client.Scan(integrationFolderID); err != nil {
		t.Fatalf("initial helper scan: %v", err)
	}
	if err := os.WriteFile(os.Getenv("OBS_SYNC_READY_FILE"), []byte("ready"), 0o600); err != nil {
		t.Fatalf("signal helper readiness: %v", err)
	}

	replyCreated := false
	ticker := time.NewTicker(150 * time.Millisecond)
	defer ticker.Stop()
	for range ticker.C {
		if _, err := os.Stat(os.Getenv("OBS_SYNC_STOP_FILE")); err == nil {
			return
		}
		_ = client.Scan(integrationFolderID)

		if replyCreated {
			continue
		}
		data, err := os.ReadFile(filepath.Join(vaultPath, "from-ipad.md"))
		if err != nil || string(data) != "created by the mobile-core integration node\n" {
			continue
		}
		if err := os.WriteFile(
			filepath.Join(vaultPath, "from-desktop.md"),
			[]byte("created by the independent desktop peer\n"),
			0o600,
		); err != nil {
			t.Fatalf("write helper response: %v", err)
		}
		if err := client.Scan(integrationFolderID); err != nil {
			t.Fatalf("scan helper response: %v", err)
		}
		replyCreated = true
	}
}

func newIntegrationClient(statePath, listenAddress string) (*Client, error) {
	options := defaultSyncthingEngineOptions()
	options.ListenAddresses = []string{listenAddress}
	options.GlobalAnnEnabled = false
	options.LocalAnnEnabled = false
	options.RelaysEnabled = false
	eng, err := newSyncthingEngineWithOptions(statePath, options)
	if err != nil {
		return nil, err
	}
	return newClient(eng), nil
}

func reserveTCPAddress(t *testing.T) string {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("reserve TCP address: %v", err)
	}
	address := listener.Addr().String()
	if err := listener.Close(); err != nil {
		t.Fatalf("release TCP address: %v", err)
	}
	return "tcp://" + address
}

type peerHelperEnvironment struct {
	StatePath      string
	VaultPath      string
	ListenAddress  string
	RemoteDeviceID string
	RemoteAddress  string
	ReadyFile      string
	StopFile       string
}

type peerHelperProcess struct {
	command *exec.Cmd
	output  *lockedBuffer
	exited  chan struct{}
	mu      sync.Mutex
	err     error
}

func startPeerHelper(t *testing.T, environment peerHelperEnvironment) *peerHelperProcess {
	t.Helper()
	command := exec.Command(os.Args[0], "-test.run=TestSyncthingPeerHelperProcess", "--")
	command.Env = append(os.Environ(),
		"OBS_SYNC_HELPER=1",
		"OBS_SYNC_STATE_PATH="+environment.StatePath,
		"OBS_SYNC_VAULT_PATH="+environment.VaultPath,
		"OBS_SYNC_LISTEN_ADDRESS="+environment.ListenAddress,
		"OBS_SYNC_REMOTE_DEVICE_ID="+environment.RemoteDeviceID,
		"OBS_SYNC_REMOTE_ADDRESS="+environment.RemoteAddress,
		"OBS_SYNC_READY_FILE="+environment.ReadyFile,
		"OBS_SYNC_STOP_FILE="+environment.StopFile,
	)
	output := &lockedBuffer{}
	command.Stdout = output
	command.Stderr = output
	if err := command.Start(); err != nil {
		t.Fatalf("start helper process: %v", err)
	}
	helper := &peerHelperProcess{
		command: command,
		output:  output,
		exited:  make(chan struct{}),
	}
	go func() {
		err := command.Wait()
		helper.mu.Lock()
		helper.err = err
		helper.mu.Unlock()
		close(helper.exited)
	}()
	return helper
}

type lockedBuffer struct {
	mu     sync.Mutex
	buffer bytes.Buffer
}

func (b *lockedBuffer) Write(data []byte) (int, error) {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buffer.Write(data)
}

func (b *lockedBuffer) String() string {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.buffer.String()
}

func (p *peerHelperProcess) stop(t *testing.T, stopFile string) {
	t.Helper()
	if err := os.WriteFile(stopFile, []byte("stop"), 0o600); err != nil {
		t.Errorf("signal helper stop: %v", err)
	}
	select {
	case <-p.exited:
		p.mu.Lock()
		err := p.err
		p.mu.Unlock()
		if err != nil {
			t.Errorf("helper process exit: %v\n%s", err, p.output.String())
		}
	case <-time.After(10 * time.Second):
		_ = p.command.Process.Kill()
		<-p.exited
		t.Errorf("helper process did not stop in time\n%s", p.output.String())
	}
}

func waitForPath(t *testing.T, path string, helper *peerHelperProcess, timeout time.Duration) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if _, err := os.Stat(path); err == nil {
			return
		}
		assertHelperRunning(t, helper)
		time.Sleep(100 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s\n%s", path, helper.output.String())
}

func waitForContent(
	t *testing.T,
	path string,
	want string,
	helper *peerHelperProcess,
	tick func(),
	timeout time.Duration,
) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if tick != nil {
			tick()
		}
		if data, err := os.ReadFile(path); err == nil && string(data) == want {
			return
		}
		assertHelperRunning(t, helper)
		time.Sleep(150 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for verified content at %s\n%s", path, helper.output.String())
}

func assertHelperRunning(t *testing.T, helper *peerHelperProcess) {
	t.Helper()
	select {
	case <-helper.exited:
		helper.mu.Lock()
		err := helper.err
		helper.mu.Unlock()
		t.Fatalf("helper process exited early: %v\n%s", err, helper.output.String())
	default:
	}
}
