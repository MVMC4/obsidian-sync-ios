// Package mobilecore provides the narrow API that will be bound for Swift.
package mobilecore

import (
	"encoding/json"
	"errors"
	"fmt"
	"sync"
)

const (
	StateIdle     = "idle"
	StateStarting = "starting"
	StateRunning  = "running"
	StateStopping = "stopping"
	StateStopped  = "stopped"
	StateFailed   = "failed"
)

var (
	errBusy          = errors.New("engine lifecycle operation already in progress")
	errNoEngine      = errors.New("syncthing engine is not configured")
	errTerminalState = errors.New("client cannot restart after stopping or failing")
	errNotRunning    = errors.New("syncthing engine is not running")
)

// engine is deliberately smaller than Syncthing's application type. The
// adapter added in the next milestone will satisfy this interface.
type engine interface {
	Start() error
	Stop() error
	DeviceID() string
}

type configurationEngine interface {
	ConfigurePeer(deviceID, name, addressesJSON string) error
	ConfigureFolder(folderID, folderPath, label, peerDeviceID string) error
	Scan(folderID string) error
	FolderStatusJSON(folderID, peerDeviceID string) (string, error)
}

// Client serializes lifecycle operations and projects engine state into values
// that gomobile can expose safely.
type Client struct {
	mu        sync.RWMutex
	engine    engine
	state     string
	lastError string
}

type statusSnapshot struct {
	SchemaVersion int    `json:"schemaVersion"`
	State         string `json:"state"`
	DeviceID      string `json:"deviceID"`
	LastError     string `json:"lastError,omitempty"`
}

func newClient(eng engine) *Client {
	return &Client{
		engine: eng,
		state:  StateIdle,
	}
}

// NewClient creates a mobile client whose private Syncthing state is rooted at
// statePath. The path must be in the application's own container, not inside a
// synchronized vault.
func NewClient(statePath string) (*Client, error) {
	eng, err := newSyncthingEngine(statePath)
	if err != nil {
		return nil, err
	}
	return newClient(eng), nil
}

// Start starts the configured engine once. Repeated calls while already
// running are harmless; overlapping lifecycle operations return an error.
func (c *Client) Start() error {
	c.mu.Lock()
	switch c.state {
	case StateRunning:
		c.mu.Unlock()
		return nil
	case StateStarting, StateStopping:
		c.mu.Unlock()
		return errBusy
	case StateStopped, StateFailed:
		c.mu.Unlock()
		return errTerminalState
	}

	if c.engine == nil {
		c.state = StateFailed
		c.lastError = errNoEngine.Error()
		c.mu.Unlock()
		return errNoEngine
	}

	c.state = StateStarting
	c.lastError = ""
	c.mu.Unlock()

	if err := c.engine.Start(); err != nil {
		c.mu.Lock()
		c.state = StateFailed
		c.lastError = err.Error()
		c.mu.Unlock()
		return fmt.Errorf("start engine: %w", err)
	}

	c.mu.Lock()
	c.state = StateRunning
	c.mu.Unlock()
	return nil
}

// Stop stops a running engine. It is idempotent when the client has not started
// or has already stopped.
func (c *Client) Stop() error {
	c.mu.Lock()
	switch c.state {
	case StateIdle, StateStopped:
		c.state = StateStopped
		c.mu.Unlock()
		return nil
	case StateStarting, StateStopping:
		c.mu.Unlock()
		return errBusy
	case StateFailed:
		c.mu.Unlock()
		return nil
	}

	c.state = StateStopping
	c.mu.Unlock()

	if err := c.engine.Stop(); err != nil {
		c.mu.Lock()
		c.state = StateFailed
		c.lastError = err.Error()
		c.mu.Unlock()
		return fmt.Errorf("stop engine: %w", err)
	}

	c.mu.Lock()
	c.state = StateStopped
	c.mu.Unlock()
	return nil
}

// State returns the current stable lifecycle label.
func (c *Client) State() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.state
}

// DeviceID returns the engine's Syncthing device ID when one is available.
func (c *Client) DeviceID() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	if c.engine == nil {
		return ""
	}
	return c.engine.DeviceID()
}

// LastError returns the last lifecycle error without exposing a Go error value
// across the mobile bridge.
func (c *Client) LastError() string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.lastError
}

// ConfigurePeer adds or updates a Syncthing peer. addressesJSON is a JSON array
// of Syncthing address strings; an empty string selects dynamic discovery.
func (c *Client) ConfigurePeer(deviceID, name, addressesJSON string) error {
	eng, err := c.runningConfigurationEngine()
	if err != nil {
		return err
	}
	return eng.ConfigurePeer(deviceID, name, addressesJSON)
}

// ConfigureFolder maps a selected vault path to a Syncthing folder and shares
// it with one configured peer.
func (c *Client) ConfigureFolder(folderID, folderPath, label, peerDeviceID string) error {
	eng, err := c.runningConfigurationEngine()
	if err != nil {
		return err
	}
	return eng.ConfigureFolder(folderID, folderPath, label, peerDeviceID)
}

// Scan requests an immediate scan of a configured vault folder.
func (c *Client) Scan(folderID string) error {
	eng, err := c.runningConfigurationEngine()
	if err != nil {
		return err
	}
	return eng.Scan(folderID)
}

// FolderStatusJSON returns a versioned sync snapshot for one configured vault
// and peer. It is intended for foreground polling by the Swift session
// controller.
func (c *Client) FolderStatusJSON(folderID, peerDeviceID string) (string, error) {
	eng, err := c.runningConfigurationEngine()
	if err != nil {
		return "", err
	}
	return eng.FolderStatusJSON(folderID, peerDeviceID)
}

func (c *Client) runningConfigurationEngine() (configurationEngine, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()
	if c.state != StateRunning {
		return nil, errNotRunning
	}
	eng, ok := c.engine.(configurationEngine)
	if !ok {
		return nil, errors.New("engine does not support configuration")
	}
	return eng, nil
}

// StatusJSON returns a versioned snapshot for the Swift presentation layer.
func (c *Client) StatusJSON() string {
	c.mu.RLock()
	snapshot := statusSnapshot{
		SchemaVersion: 1,
		State:         c.state,
		LastError:     c.lastError,
	}
	if c.engine != nil {
		snapshot.DeviceID = c.engine.DeviceID()
	}
	c.mu.RUnlock()

	data, err := json.Marshal(snapshot)
	if err != nil {
		// The snapshot currently contains only JSON-safe primitive values. Keep a
		// deterministic fallback in case that contract changes accidentally.
		return `{"schemaVersion":1,"state":"failed","lastError":"status encoding failed"}`
	}
	return string(data)
}
