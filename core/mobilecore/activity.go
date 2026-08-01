package mobilecore

import (
	"encoding/json"
	"errors"
	"path"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/syncthing/syncthing/lib/events"
)

const maximumRecentActivityItems = 40

type activityItem struct {
	Path        string `json:"path"`
	Direction   string `json:"direction"`
	Action      string `json:"action"`
	ItemType    string `json:"itemType"`
	Result      string `json:"result"`
	CompletedAt string `json:"completedAt"`
}

type activitySnapshot struct {
	SchemaVersion int            `json:"schemaVersion"`
	FolderID      string         `json:"folderID"`
	Items         []activityItem `json:"items"`
}

type activityRecorder struct {
	mu    sync.RWMutex
	items map[string][]activityItem
}

func newActivityRecorder() *activityRecorder {
	return &activityRecorder{items: make(map[string][]activityItem)}
}

func (r *activityRecorder) record(event events.Event) {
	folder, ok := activityStringField(event.Data, "folder")
	if !ok || strings.TrimSpace(folder) == "" {
		return
	}

	var rawPath, direction, action, itemType, result string
	switch event.Type {
	case events.LocalChangeDetected:
		rawPath, ok = activityStringField(event.Data, "path")
		direction = "outgoing"
		action, _ = activityStringField(event.Data, "action")
		itemType, _ = activityStringField(event.Data, "type")
		result = "detected"
	case events.ItemFinished:
		rawPath, ok = activityStringField(event.Data, "item")
		direction = "incoming"
		action, _ = activityStringField(event.Data, "action")
		itemType, _ = activityStringField(event.Data, "type")
		result = "completed"
		if activityErrorPresent(event.Data) {
			result = "failed"
		}
	default:
		return
	}
	if !ok {
		return
	}

	relativePath, ok := safeActivityPath(rawPath)
	if !ok {
		return
	}
	item := activityItem{
		Path:        relativePath,
		Direction:   direction,
		Action:      normalizedActivityAction(action),
		ItemType:    normalizedActivityType(itemType),
		Result:      result,
		CompletedAt: event.Time.UTC().Format(time.RFC3339Nano),
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	items := r.items[folder]
	for index := len(items) - 1; index >= 0; index-- {
		if items[index].Path == item.Path &&
			items[index].Direction == item.Direction &&
			items[index].Action == item.Action {
			items = slices.Delete(items, index, index+1)
			break
		}
	}
	items = append(items, item)
	if len(items) > maximumRecentActivityItems {
		items = items[len(items)-maximumRecentActivityItems:]
	}
	r.items[folder] = items
}

func (r *activityRecorder) snapshot(folderID string) activitySnapshot {
	r.mu.RLock()
	items := append([]activityItem(nil), r.items[folderID]...)
	r.mu.RUnlock()
	slices.Reverse(items)
	return activitySnapshot{
		SchemaVersion: 1,
		FolderID:      folderID,
		Items:         items,
	}
}

func (e *syncthingEngine) RecentActivityJSON(folderID string) (string, error) {
	folderID = strings.TrimSpace(folderID)
	if folderID == "" {
		return "", errors.New("folder ID is empty")
	}
	if e.activity == nil {
		return "", errNotRunning
	}
	if _, ok := e.config.Folder(folderID); !ok {
		return "", errors.New("folder is not configured")
	}
	payload, err := json.Marshal(e.activity.snapshot(folderID))
	if err != nil {
		return "", err
	}
	return string(payload), nil
}

func activityStringField(data any, key string) (string, bool) {
	switch value := data.(type) {
	case map[string]string:
		field, ok := value[key]
		return field, ok
	case map[string]interface{}:
		field, ok := value[key].(string)
		return field, ok
	default:
		return "", false
	}
}

func activityErrorPresent(data any) bool {
	value, ok := data.(map[string]interface{})
	if !ok {
		return false
	}
	errorValue, exists := value["error"]
	if !exists || errorValue == nil {
		return false
	}
	if text, ok := errorValue.(*string); ok {
		return text != nil && *text != ""
	}
	return true
}

func safeActivityPath(value string) (string, bool) {
	value = strings.ReplaceAll(strings.TrimSpace(value), `\`, "/")
	cleaned := path.Clean(value)
	if cleaned == "." || cleaned == "" || path.IsAbs(cleaned) ||
		cleaned == ".." || strings.HasPrefix(cleaned, "../") {
		return "", false
	}
	firstComponent := strings.SplitN(cleaned, "/", 2)[0]
	if strings.Contains(firstComponent, ":") {
		return "", false
	}
	return cleaned, true
}

func normalizedActivityAction(value string) string {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "delete", "deleted":
		return "deleted"
	case "update", "updated":
		return "updated"
	case "modified", "modify":
		return "modified"
	default:
		return "changed"
	}
}

func normalizedActivityType(value string) string {
	switch strings.ToLower(strings.TrimSpace(value)) {
	case "dir", "directory":
		return "directory"
	case "symlink":
		return "symlink"
	default:
		return "file"
	}
}
