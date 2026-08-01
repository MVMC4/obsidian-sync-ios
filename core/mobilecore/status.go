package mobilecore

import (
	"encoding/json"
	"errors"
	"fmt"
	"math"
	"strings"
	"time"

	"github.com/syncthing/syncthing/lib/protocol"
)

type folderStatusSnapshot struct {
	SchemaVersion       int     `json:"schemaVersion"`
	FolderID            string  `json:"folderID"`
	FolderState         string  `json:"folderState"`
	StateChangedAt      string  `json:"stateChangedAt"`
	PeerConnected       bool    `json:"peerConnected"`
	LocalCompletionPct  float64 `json:"localCompletionPct"`
	RemoteCompletionPct float64 `json:"remoteCompletionPct"`
	GlobalBytes         int64   `json:"globalBytes"`
	NeedBytes           int64   `json:"needBytes"`
	NeedItems           int     `json:"needItems"`
	NeedDeletes         int     `json:"needDeletes"`
	RemoteNeedBytes     int64   `json:"remoteNeedBytes"`
	RemoteNeedItems     int     `json:"remoteNeedItems"`
	RemoteNeedDeletes   int     `json:"remoteNeedDeletes"`
	UpToDate            bool    `json:"upToDate"`
}

func (e *syncthingEngine) FolderStatusJSON(folderID, peerDeviceID string) (string, error) {
	if e.app == nil || e.app.Internals == nil || e.config == nil {
		return "", errNotRunning
	}

	folderID = strings.TrimSpace(folderID)
	if _, ok := e.config.Folder(folderID); !ok {
		return "", errors.New("folder is not configured")
	}

	peerID, err := protocol.DeviceIDFromString(strings.TrimSpace(peerDeviceID))
	if err != nil {
		return "", fmt.Errorf("parse status peer device ID: %w", err)
	}
	if _, ok := e.config.Device(peerID); !ok {
		return "", errors.New("status peer is not configured")
	}

	folderState, changedAt, err := e.app.Internals.FolderState(folderID)
	if err != nil {
		return "", fmt.Errorf("read folder state: %w", err)
	}
	global, err := e.app.Internals.GlobalSize(folderID)
	if err != nil {
		return "", fmt.Errorf("read global size: %w", err)
	}
	localNeed, err := e.app.Internals.NeedSize(folderID, protocol.LocalDeviceID)
	if err != nil {
		return "", fmt.Errorf("read local need: %w", err)
	}
	remote, err := e.app.Internals.Completion(peerID, folderID)
	if err != nil {
		return "", fmt.Errorf("read remote completion: %w", err)
	}

	peerConnected := e.app.Internals.IsConnectedTo(peerID)
	localCompletion := completionPercentage(global.Bytes, localNeed.Bytes, localNeed.Deleted)
	localNeedItems := localNeed.Files + localNeed.Directories + localNeed.Symlinks
	snapshot := folderStatusSnapshot{
		SchemaVersion:       1,
		FolderID:            folderID,
		FolderState:         folderState,
		StateChangedAt:      changedAt.UTC().Format(time.RFC3339Nano),
		PeerConnected:       peerConnected,
		LocalCompletionPct:  localCompletion,
		RemoteCompletionPct: remote.CompletionPct,
		GlobalBytes:         global.Bytes,
		NeedBytes:           localNeed.Bytes,
		NeedItems:           localNeedItems,
		NeedDeletes:         localNeed.Deleted,
		RemoteNeedBytes:     remote.NeedBytes,
		RemoteNeedItems:     remote.NeedItems,
		RemoteNeedDeletes:   remote.NeedDeletes,
	}
	snapshot.UpToDate = peerConnected &&
		folderState == "idle" &&
		localNeedItems == 0 &&
		localNeed.Deleted == 0 &&
		remote.NeedItems == 0 &&
		remote.NeedDeletes == 0 &&
		localCompletion == 100 &&
		remote.CompletionPct == 100

	data, err := json.Marshal(snapshot)
	if err != nil {
		return "", fmt.Errorf("encode folder status: %w", err)
	}
	return string(data), nil
}

func completionPercentage(globalBytes, needBytes int64, needDeletes int) float64 {
	if globalBytes <= 0 {
		if needDeletes > 0 {
			return 95
		}
		return 100
	}
	completion := 100 * (1 - float64(needBytes)/float64(globalBytes))
	if needBytes == 0 && needDeletes > 0 {
		return 95
	}
	return math.Max(0, math.Min(100, completion))
}
