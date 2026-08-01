package mobilecore

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/syncthing/syncthing/lib/config"
	"github.com/syncthing/syncthing/lib/protocol"
)

func (e *syncthingEngine) ConfigurePeer(deviceID, name, addressesJSON string) error {
	peerID, err := protocol.DeviceIDFromString(strings.TrimSpace(deviceID))
	if err != nil {
		return fmt.Errorf("parse peer device ID: %w", err)
	}
	if peerID.String() == e.deviceID {
		return errors.New("peer device ID matches this device")
	}

	addresses, err := parseAddresses(addressesJSON)
	if err != nil {
		return err
	}

	peer := e.config.DefaultDevice()
	peer.DeviceID = peerID
	peer.Name = strings.TrimSpace(name)
	peer.Addresses = addresses
	peer.Paused = false

	return e.modifyConfiguration(func(current *config.Configuration) {
		current.SetDevice(peer)
	})
}

func (e *syncthingEngine) ConfigureFolder(folderID, folderPath, label, peerDeviceID string) error {
	folderID = strings.TrimSpace(folderID)
	if folderID == "" {
		return errors.New("folder ID is empty")
	}

	absPath, err := filepath.Abs(folderPath)
	if err != nil {
		return fmt.Errorf("resolve folder path: %w", err)
	}
	info, err := os.Stat(absPath)
	if err != nil {
		return fmt.Errorf("inspect folder path: %w", err)
	}
	if !info.IsDir() {
		return errors.New("folder path is not a directory")
	}

	peerID, err := protocol.DeviceIDFromString(strings.TrimSpace(peerDeviceID))
	if err != nil {
		return fmt.Errorf("parse folder peer device ID: %w", err)
	}
	if _, ok := e.config.Device(peerID); !ok {
		return errors.New("folder peer is not configured")
	}

	folder := e.config.DefaultFolder()
	folder.ID = folderID
	folder.Label = strings.TrimSpace(label)
	if folder.Label == "" {
		folder.Label = folderID
	}
	folder.Path = absPath
	folder.Type = config.FolderTypeSendReceive
	folder.Paused = false
	folder.IgnorePerms = true
	folder.FSWatcherEnabled = false
	folder.RescanIntervalS = 0
	folder.ScanProgressIntervalS = -1
	folder.Devices = []config.FolderDeviceConfiguration{{DeviceID: peerID}}

	return e.modifyConfiguration(func(current *config.Configuration) {
		current.SetFolder(folder)
	})
}

func (e *syncthingEngine) Scan(folderID string) error {
	if e.app == nil || e.app.Internals == nil {
		return errNotRunning
	}
	if _, ok := e.config.Folder(strings.TrimSpace(folderID)); !ok {
		return errors.New("folder is not configured")
	}
	return e.app.Internals.ScanFolderSubdirs(folderID, nil)
}

func (e *syncthingEngine) modifyConfiguration(modify config.ModifyFunction) error {
	if e.config == nil {
		return errNotRunning
	}
	waiter, err := e.config.Modify(modify)
	if err != nil {
		return fmt.Errorf("modify configuration: %w", err)
	}
	waiter.Wait()
	if err := e.config.Save(); err != nil {
		return fmt.Errorf("save configuration: %w", err)
	}
	return nil
}

func parseAddresses(addressesJSON string) ([]string, error) {
	if strings.TrimSpace(addressesJSON) == "" {
		return []string{"dynamic"}, nil
	}

	var addresses []string
	if err := json.Unmarshal([]byte(addressesJSON), &addresses); err != nil {
		return nil, fmt.Errorf("parse peer addresses JSON: %w", err)
	}
	if len(addresses) == 0 {
		return []string{"dynamic"}, nil
	}
	for _, address := range addresses {
		if strings.TrimSpace(address) == "" {
			return nil, errors.New("peer address is empty")
		}
	}
	return addresses, nil
}
