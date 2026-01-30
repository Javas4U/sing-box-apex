package accesslog

import (
	"context"
	stdjson "encoding/json"
	"net"
	"sync"
	"time"

	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing/common/auth"
	F "github.com/sagernet/sing/common/format"
	"github.com/sagernet/sing/common/json"
	N "github.com/sagernet/sing/common/network"
)

var _ adapter.ConnectionTracker = (*Tracker)(nil)
var _ adapter.LifecycleService = (*Tracker)(nil)

type Tracker struct {
	logger  log.ContextLogger
	options option.AccessLogOptions
	writer  *log.RotatingWriter
	access  sync.Mutex
	userMap map[string][]any
}

func NewTracker(ctx context.Context, logger log.ContextLogger, options option.AccessLogOptions, inbounds []option.Inbound) *Tracker {
	t := &Tracker{
		logger:  logger,
		options: options,
		userMap: make(map[string][]any),
	}
	t.buildUserMap(inbounds)
	return t
}

func (t *Tracker) buildUserMap(inbounds []option.Inbound) {
	for _, inbound := range inbounds {
		if inbound.Options == nil {
			continue
		}
		data, err := stdjson.Marshal(inbound.Options)
		if err != nil {
			continue
		}
		var optionsMap map[string]any
		if err := stdjson.Unmarshal(data, &optionsMap); err != nil {
			continue
		}
		users, ok := optionsMap["users"].([]any)
		if ok {
			t.userMap[inbound.Tag] = users
		}
	}
}

func (t *Tracker) Name() string {
	return "access-log"
}

func (t *Tracker) Start(stage adapter.StartStage) error {
	if stage != adapter.StartStateStart {
		return nil
	}
	if t.options.Path != "" {
		t.writer = log.NewRotatingWriter(context.Background(), t.options.Path, log.RotateHourly)
	}
	return nil
}

func (t *Tracker) Close() error {
	if t.writer != nil {
		return t.writer.Close()
	}
	return nil
}

func (t *Tracker) RoutedConnection(ctx context.Context, conn net.Conn, metadata adapter.InboundContext, matchedRule adapter.Rule, matchOutbound adapter.Outbound) net.Conn {
	t.logConnection(ctx, "tcp", metadata, matchedRule, matchOutbound)
	return conn
}

func (t *Tracker) RoutedPacketConnection(ctx context.Context, conn N.PacketConn, metadata adapter.InboundContext, matchedRule adapter.Rule, matchOutbound adapter.Outbound) N.PacketConn {
	t.logConnection(ctx, "udp", metadata, matchedRule, matchOutbound)
	return conn
}

type LogEntry struct {
	Time      time.Time `json:"time"`
	Inbound   string    `json:"inbound"`
	Type      string    `json:"type"`
	User      any       `json:"user,omitempty"`
	Network   string    `json:"network"`
	Address   string    `json:"address"`
	Action    string    `json:"action"`
	Rule      string    `json:"rule,omitempty"`
	Outbound  string    `json:"outbound,omitempty"`
}

func (t *Tracker) logConnection(ctx context.Context, network string, metadata adapter.InboundContext, matchedRule adapter.Rule, matchOutbound adapter.Outbound) {
	entry := LogEntry{
		Time:    time.Now(),
		Inbound: metadata.Inbound,
		Type:    metadata.InboundType,
		Network: network,
		Address: metadata.Destination.String(),
	}

	// Try to resolve full user details
	userIndex, loaded := auth.UserFromContext[int](ctx)
	if loaded {
		if users, ok := t.userMap[metadata.Inbound]; ok && userIndex >= 0 && userIndex < len(users) {
			entry.User = users[userIndex]
		}
	}

	// Fallback to metadata.User if full details not found
	if entry.User == nil && metadata.User != "" {
		entry.User = metadata.User
	}

	if matchedRule != nil {
		entry.Rule = F.ToString(matchedRule, " (", matchedRule.Action(), ")")
		entry.Action = matchedRule.Action().Type()
	} else {
		entry.Action = "route"
		entry.Rule = "final"
	}

	if matchOutbound != nil {
		entry.Outbound = matchOutbound.Tag()
	}

	if t.writer != nil {
		t.access.Lock()
		defer t.access.Unlock()
		encoder := json.NewEncoder(t.writer)
		_ = encoder.Encode(entry)
	} else {
		if matchedRule != nil {
			t.logger.InfoContext(ctx,
				"access-log: inbound=", metadata.Inbound,
				" type=", metadata.InboundType,
				" user=", entry.User,
				" network=", network,
				" address=", metadata.Destination,
				" rule=", entry.Rule,
				" outbound=", entry.Outbound,
			)
		} else {
			t.logger.InfoContext(ctx,
				"access-log: inbound=", metadata.Inbound,
				" type=", metadata.InboundType,
				" user=", entry.User,
				" network=", network,
				" address=", metadata.Destination,
				" rule=final",
				" outbound=", entry.Outbound,
			)
		}
	}
}
