package log

import (
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/sagernet/sing/service/filemanager"
)

// RotateStrategy 日志轮转策略
type RotateStrategy string

const (
	RotateNone   RotateStrategy = "none"   // 不轮转
	RotateHourly RotateStrategy = "hourly" // 按小时轮转
	RotateDaily  RotateStrategy = "daily"  // 按天轮转
)

// RotatingWriter 支持日志轮转的 Writer
type RotatingWriter struct {
	ctx          context.Context
	baseFilePath string          // 基础文件路径,如 /var/log/sing-box.log
	strategy     RotateStrategy  // 轮转策略
	currentFile  *os.File        // 当前打开的文件
	currentHour  int             // 当前文件对应的小时
	currentDay   int             // 当前文件对应的天
	mu           sync.Mutex      // 保护并发写入
}

// NewRotatingWriter 创建一个支持日志轮转的 Writer
func NewRotatingWriter(ctx context.Context, filePath string, strategy RotateStrategy) *RotatingWriter {
	return &RotatingWriter{
		ctx:          ctx,
		baseFilePath: filePath,
		strategy:     strategy,
		currentHour:  -1,
		currentDay:   -1,
	}
}

// getRotatedFilePath 根据策略生成带时间戳的文件路径
func (w *RotatingWriter) getRotatedFilePath(t time.Time) string {
	if w.strategy == RotateNone {
		return w.baseFilePath
	}

	ext := filepath.Ext(w.baseFilePath)
	nameWithoutExt := w.baseFilePath[:len(w.baseFilePath)-len(ext)]

	switch w.strategy {
	case RotateHourly:
		// 格式: sing-box-2025-12-19-14.log
		timestamp := t.Format("2006-01-02-15")
		return fmt.Sprintf("%s-%s%s", nameWithoutExt, timestamp, ext)
	case RotateDaily:
		// 格式: sing-box-2025-12-19.log
		timestamp := t.Format("2006-01-02")
		return fmt.Sprintf("%s-%s%s", nameWithoutExt, timestamp, ext)
	default:
		return w.baseFilePath
	}
}

// shouldRotate 检查是否需要轮转
func (w *RotatingWriter) shouldRotate(now time.Time) bool {
	if w.strategy == RotateNone {
		return false
	}

	switch w.strategy {
	case RotateHourly:
		hour := now.Hour()
		if w.currentHour == -1 {
			w.currentHour = hour
			return false
		}
		return hour != w.currentHour
	case RotateDaily:
		day := now.YearDay()
		if w.currentDay == -1 {
			w.currentDay = day
			return false
		}
		return day != w.currentDay
	}

	return false
}

// rotate 执行日志轮转
func (w *RotatingWriter) rotate(now time.Time) error {
	// 关闭当前文件
	if w.currentFile != nil {
		if err := w.currentFile.Close(); err != nil {
			return err
		}
		w.currentFile = nil
	}

	// 打开新文件
	newFilePath := w.getRotatedFilePath(now)
	logFile, err := filemanager.OpenFile(w.ctx, newFilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}

	w.currentFile = logFile

	// 更新当前时间标记
	switch w.strategy {
	case RotateHourly:
		w.currentHour = now.Hour()
	case RotateDaily:
		w.currentDay = now.YearDay()
	}

	return nil
}

// Write 实现 io.Writer 接口
func (w *RotatingWriter) Write(p []byte) (n int, err error) {
	w.mu.Lock()
	defer w.mu.Unlock()

	now := time.Now()

	// 检查是否需要轮转
	if w.currentFile == nil || w.shouldRotate(now) {
		if err := w.rotate(now); err != nil {
			return 0, err
		}
	}

	// 写入数据
	return w.currentFile.Write(p)
}

// Close 关闭当前打开的文件
func (w *RotatingWriter) Close() error {
	w.mu.Lock()
	defer w.mu.Unlock()

	if w.currentFile != nil {
		return w.currentFile.Close()
	}
	return nil
}

// Ensure RotatingWriter implements io.WriteCloser
var _ io.WriteCloser = (*RotatingWriter)(nil)
