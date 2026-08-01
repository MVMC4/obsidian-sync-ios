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
	errBusy     = errors.New("engine lifecycle operation already in progress")
	errNoEngine = errors.New("syncthing engine is not configured")
)

// engine is deliberately smaller than Syncthing's application type. The
// adapter added in the next milestone will satisfy this interface.
type engine interface {
	Start() error
	Stop() error
	DeviceID() string
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
