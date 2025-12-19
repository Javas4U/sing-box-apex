# 日志轮转功能说明

## 概述

sing-box-apex 现已支持按时间自动轮转日志文件,避免单个日志文件过大。

## 功能特性

- **按小时轮转** (`hourly`): 每小时自动创建新的日志文件
- **按天轮转** (`daily`): 每天自动创建新的日志文件
- **不轮转** (`none`): 保持原有行为,所有日志写入单一文件(默认)

## 配置方式

在配置文件的 `log` 部分添加 `rotate_strategy` 字段:

```json
{
  "log": {
    "disabled": false,
    "level": "info",
    "output": "/var/log/sing-box.log",
    "timestamp": true,
    "rotate_strategy": "hourly"
  }
}
```

## 配置选项

### `rotate_strategy`

可选值:
- `"none"` 或留空 - 不使用日志轮转(默认)
- `"hourly"` - 按小时轮转
- `"daily"` - 按天轮转

## 文件命名规则

### 按小时轮转 (`hourly`)

原始配置: `/var/log/sing-box.log`

生成的文件名格式: `/var/log/sing-box-2025-12-19-14.log`

示例:
- `sing-box-2025-12-19-14.log` (2025年12月19日14点)
- `sing-box-2025-12-19-15.log` (2025年12月19日15点)
- `sing-box-2025-12-19-16.log` (2025年12月19日16点)

### 按天轮转 (`daily`)

原始配置: `/var/log/sing-box.log`

生成的文件名格式: `/var/log/sing-box-2025-12-19.log`

示例:
- `sing-box-2025-12-19.log` (2025年12月19日)
- `sing-box-2025-12-20.log` (2025年12月20日)
- `sing-box-2025-12-21.log` (2025年12月21日)

## 工作原理

1. **自动检测**: 每次写入日志时自动检测当前时间
2. **智能切换**: 当时间跨越到新的小时/天时,自动关闭旧文件并创建新文件
3. **并发安全**: 使用互斥锁保护,支持并发写入
4. **零配置**: 无需手动创建目录或文件,系统自动处理

## 实现细节

### 核心组件

- **`RotatingWriter`**: 日志轮转写入器,实现 `io.WriteCloser` 接口
- **`RotateStrategy`**: 轮转策略枚举类型
- **文件路径生成**: 根据策略和时间戳自动生成文件路径
- **自动轮转**: 在每次写入时检查是否需要轮转

### 修改的文件

1. **`log/rotation.go`** - 新增文件,包含日志轮转核心逻辑
2. **`log/observable.go`** - 修改 `defaultFactory` 集成轮转功能
3. **`log/log.go`** - 添加轮转策略解析逻辑
4. **`option/options.go`** - 添加 `RotateStrategy` 配置字段

## 使用示例

### 示例 1: 按小时轮转

```json
{
  "log": {
    "level": "debug",
    "output": "/var/log/sing-box.log",
    "timestamp": true,
    "rotate_strategy": "hourly"
  }
}
```

这将在每小时整点时自动创建新的日志文件。

### 示例 2: 按天轮转

```json
{
  "log": {
    "level": "info",
    "output": "/var/log/sing-box.log",
    "timestamp": true,
    "rotate_strategy": "daily"
  }
}
```

这将在每天零点时自动创建新的日志文件。

### 示例 3: 不使用轮转(默认行为)

```json
{
  "log": {
    "level": "info",
    "output": "/var/log/sing-box.log",
    "timestamp": true
  }
}
```

或显式指定:

```json
{
  "log": {
    "level": "info",
    "output": "/var/log/sing-box.log",
    "timestamp": true,
    "rotate_strategy": "none"
  }
}
```

## 注意事项

1. **文件权限**: 确保程序对日志目录有写入权限
2. **磁盘空间**: 按小时轮转会生成更多文件,需要定期清理旧日志
3. **向后兼容**: 不配置 `rotate_strategy` 时保持原有行为
4. **输出到 stderr/stdout**: 当日志输出到标准错误或标准输出时,轮转功能不生效

## 日志清理建议

可以使用系统工具定期清理旧日志文件:

```bash
# 删除 7 天前的日志文件
find /var/log -name "sing-box-*.log" -mtime +7 -delete

# 或使用 logrotate 配置
# /etc/logrotate.d/sing-box
/var/log/sing-box-*.log {
    rotate 7
    daily
    compress
    delaycompress
    notifempty
    missingok
}
```

## 性能影响

- **轻量级检查**: 每次写入只进行简单的时间比较
- **最小开销**: 使用互斥锁保护,但锁持有时间极短
- **无额外线程**: 不需要后台任务或定时器
- **自动文件管理**: 文件创建和关闭都是自动完成的

## 技术细节

### 并发安全

使用 `sync.Mutex` 保护写入操作:

```go
func (w *RotatingWriter) Write(p []byte) (n int, err error) {
    w.mu.Lock()
    defer w.mu.Unlock()

    // 检查轮转 + 写入数据
}
```

### 时间检测逻辑

**按小时轮转**:
- 记录当前文件对应的小时数 (0-23)
- 每次写入时比较当前小时与记录的小时
- 如果不同,执行轮转

**按天轮转**:
- 记录当前文件对应的年内天数 (1-366)
- 每次写入时比较当前天数与记录的天数
- 如果不同,执行轮转

### 文件生成逻辑

```go
// 按小时: sing-box-2025-12-19-14.log
timestamp := t.Format("2006-01-02-15")
filepath := fmt.Sprintf("%s-%s%s", nameWithoutExt, timestamp, ext)

// 按天: sing-box-2025-12-19.log
timestamp := t.Format("2006-01-02")
filepath := fmt.Sprintf("%s-%s%s", nameWithoutExt, timestamp, ext)
```
