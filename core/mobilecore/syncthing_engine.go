package mobilecore

import (
	"context"
	"crypto/tls"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/syncthing/syncthing/lib/build"
	"github.com/syncthing/syncthing/lib/config"
	"github.com/syncthing/syncthing/lib/events"
	"github.com/syncthing/syncthing/lib/locations"
	"github.com/syncthing/syncthing/lib/protocol"
	"github.com/syncthing/syncthing/lib/svcutil"
	"github.com/syncthing/syncthing/lib/syncthing"
)

const embeddedSyncthingVersion = "v2.1.1"

var configureBuildMetadataOnce sync.Once

type syncthingEngine struct {
	statePath string
	certPath  string
	keyPath   string
	cert      tls.Certificate
	deviceID  string

	app      *syncthing.App
	cancel   context.CancelFunc
	config   config.Wrapper
	services sync.WaitGroup
}

func newSyncthingEngine(statePath string) (*syncthingEngine, error) {
	if strings.TrimSpace(statePath) == "" {
		return nil, errorsForPath("state path is empty")
	}

	absPath, err := filepath.Abs(statePath)
	if err != nil {
		return nil, fmt.Errorf("resolve state path: %w", err)
	}
	if err := os.MkdirAll(absPath, 0o700); err != nil {
		return nil, fmt.Errorf("create state path: %w", err)
	}

	configureBuildMetadataOnce.Do(func() {
		build.Version = embeddedSyncthingVersion
		build.Host = "github.com/MVMC4"
		build.User = "obsidian-sync-ios"
	})

	certPath := filepath.Join(absPath, "cert.pem")
	keyPath := filepath.Join(absPath, "key.pem")
	cert, err := syncthing.LoadOrGenerateCertificate(certPath, keyPath)
	if err != nil {
		return nil, fmt.Errorf("load or generate device identity: %w", err)
	}

	return &syncthingEngine{
		statePath: absPath,
		certPath:  certPath,
		keyPath:   keyPath,
		cert:      cert,
		deviceID:  protocol.NewDeviceID(cert.Certificate[0]).String(),
	}, nil
}

func errorsForPath(message string) error {
	return fmt.Errorf("invalid state path: %s", message)
}

func (e *syncthingEngine) Start() error {
	if err := e.configureLocations(); err != nil {
		return err
	}

	ctx, cancel := context.WithCancel(context.Background())
	e.cancel = cancel
	eventLogger := events.NewLogger()
	e.services.Add(1)
	go func() {
		defer e.services.Done()
		_ = eventLogger.Serve(ctx)
	}()

	cfg, err := syncthing.LoadConfigAtStartup(
		locations.Get(locations.ConfigFile),
		e.cert,
		eventLogger,
		false,
		true,
	)
	if err != nil {
		e.stopSupportingServices()
		return fmt.Errorf("load configuration: %w", err)
	}
	e.services.Add(1)
	go func() {
		defer e.services.Done()
		_ = cfg.Serve(ctx)
	}()

	waiter, err := cfg.Modify(func(current *config.Configuration) {
		current.GUI.Enabled = false
		// QUIC relies on STUN, whose current upstream shutdown path races under
		// the Go race detector. TCP plus discovery and relays is sufficient for
		// the foreground-first MVP and avoids starting that subsystem.
		current.Options.RawListenAddresses = []string{"tcp://:22000"}
		current.Options.NATEnabled = false
		current.Options.AutoUpgradeIntervalH = 0
		current.Options.CREnabled = false
		current.Options.URAccepted = -1
	})
	if err != nil {
		e.stopSupportingServices()
		return fmt.Errorf("configure mobile defaults: %w", err)
	}
	waiter.Wait()
	if err := cfg.Save(); err != nil {
		e.stopSupportingServices()
		return fmt.Errorf("save mobile configuration: %w", err)
	}

	const deleteRetention = 180 * 24 * time.Hour
	database, err := syncthing.OpenDatabase(locations.Get(locations.Database), deleteRetention)
	if err != nil {
		e.stopSupportingServices()
		return fmt.Errorf("open database: %w", err)
	}

	app, err := syncthing.New(cfg, database, eventLogger, e.cert, syncthing.Options{
		NoUpgrade:             true,
		DBMaintenanceInterval: 0,
	})
	if err != nil {
		database.Close()
		e.stopSupportingServices()
		return fmt.Errorf("create syncthing application: %w", err)
	}
	e.app = app
	e.config = cfg

	if err := app.Start(); err != nil {
		e.stopSupportingServices()
		return fmt.Errorf("start syncthing application: %w", err)
	}
	return nil
}

func (e *syncthingEngine) Stop() error {
	if e.app == nil {
		e.stopSupportingServices()
		return nil
	}

	e.app.Stop(svcutil.ExitSuccess)
	e.stopSupportingServices()
	return e.app.Error()
}

func (e *syncthingEngine) stopSupportingServices() {
	if e.cancel != nil {
		e.cancel()
	}
	e.services.Wait()
}

func (e *syncthingEngine) DeviceID() string {
	return e.deviceID
}

func (e *syncthingEngine) configureLocations() error {
	for name, location := range map[locations.BaseDirEnum]string{
		locations.ConfigBaseDir:   e.statePath,
		locations.DataBaseDir:     e.statePath,
		locations.UserHomeBaseDir: e.statePath,
	} {
		if err := locations.SetBaseDir(name, location); err != nil {
			return fmt.Errorf("configure %s directory: %w", name, err)
		}
	}
	return nil
}
