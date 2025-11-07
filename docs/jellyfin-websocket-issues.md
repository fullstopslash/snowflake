# Jellyfin WebSocket "socket is closed" Error Documentation

## Problem Summary

The "socket is closed" errors appearing in `jellyfin-mpv-shim` logs originate from `jellyfin_apiclient_python.ws_client`, indicating that the WebSocket connection between the client and Jellyfin server is being unexpectedly terminated.

**Error Pattern:**
```
[ERROR] websocket: error from callback <function WSClient.run.<locals>.<lambda>: socket is closed
[ERROR] JELLYFIN.jellyfin_apiclient_python.ws_client: socket is closed
```

## Known Issues

### 1. Jellyfin Server Bug (GitHub Issue #12090)

- **Issue**: Jellyfin server can crash or experience issues when clients disconnect without completing the WebSocket close handshake
- **Impact**: This is a **server-side issue** that affects all clients, not specific to `jellyfin-mpv-shim`
- **Status**: Known issue in the Jellyfin ecosystem
- **Reference**: https://github.com/jellyfin/jellyfin/issues/12090

### 2. Network Configuration Issues

- **VPN Usage**: VPN connections can cause packet loss and websocket instability
- **Reverse Proxy**: Misconfigured reverse proxies (e.g., Nginx) can interrupt websocket connections
- **Reference**: https://github.com/jellyfin/jellyfin/issues/3081

### 3. Hardware Transcoding Issues

- **Incompatible Settings**: Hardware transcoding settings incompatible with your hardware (e.g., AV1 on unsupported GPUs) can disrupt websocket connections
- **Workaround**: Adjust hardware transcoding settings in Jellyfin server configuration
- **Reference**: https://forum.jellyfin.org/t-websocket-unhandeled-exception

## Current Configuration

The `jellyfin-mpv-shim` service in `roles/media.nix` is already configured with:

- `Restart = "always"` - Automatically handles reconnections when the service exits
- `RestartSec = "5s"` - Prevents rapid restart loops while recovering quickly
- Proper timeout configurations for graceful shutdown

**Current Service Configuration:**
```nix
systemd.user.services.jellyfin-mpv-shim = {
  serviceConfig = {
    Restart = "always";
    RestartSec = "5s";
    TimeoutStartSec = "30s";
    TimeoutStopSec = "10s";
  };
};
```

## Impact Assessment

### Non-Fatal Errors

The websocket errors appear to be **non-fatal**:
- The service continues running after the errors
- Media playback functionality may still work despite the errors
- The current restart policy should handle transient connection issues

### When to Investigate Further

Investigate if you experience:
- Complete service failures
- Media playback interruptions
- Frequent service restarts
- Connection timeouts affecting functionality

## Potential Mitigations

### 1. Jellyfin Server Configuration

**Check Server Logs:**
- Review Jellyfin server logs for corresponding errors at the time of client websocket errors
- Look for server-side connection issues or crashes

**Verify WebSocket Settings:**
- Check Jellyfin server websocket timeout settings
- Review connection limits and resource constraints

**Hardware Transcoding:**
- Verify hardware transcoding compatibility with your GPU
- Disable AV1 transcoding if your hardware doesn't support it
- Review transcoding settings in Jellyfin server dashboard

### 2. Network Configuration

**VPN Issues:**
- If using a VPN, test with VPN disabled to isolate the issue
- Verify VPN allows websocket traffic without packet loss
- Consider using split tunneling for Jellyfin traffic

**Reverse Proxy:**
- If using Nginx or another reverse proxy, verify websocket configuration:
  ```nginx
  location / {
      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
      proxy_set_header Host $host;
  }
  ```
- Ensure websocket connections use HTTPS when server uses HTTPS

**Firewall:**
- Verify firewall allows websocket traffic
- Check that required ports are open for Jellyfin communication

### 3. Client Configuration

**jellyfin-mpv-shim Settings:**
- Check if `jellyfin-mpv-shim` has configurable websocket timeout/reconnect settings
- Review connection settings in `~/.config/jellyfin-mpv-shim/` configuration files
- Verify client connection settings match server expectations

**Connection Stability:**
- Monitor network latency between client and server
- Test with different network conditions to identify stability issues

### 4. Monitoring and Debugging

**Service Monitoring:**
```bash
# Check service status
systemctl --user status jellyfin-mpv-shim

# View recent logs
journalctl --user -u jellyfin-mpv-shim -n 100

# Follow logs in real-time
journalctl --user -u jellyfin-mpv-shim -f
```

**Filter for Websocket Errors:**
```bash
journalctl --user -u jellyfin-mpv-shim | grep -i "websocket\|socket is closed"
```

**Test Functionality:**
- Verify media playback still works despite the errors
- Test various media types and codecs
- Check if errors correlate with specific actions (play, pause, seek)

## Workarounds

### Built-in Health Check (Already Configured)

The `jellyfin-mpv-shim` configuration file (`~/.config/jellyfin-mpv-shim/conf.json`) includes:
- `health_check_interval: 300` - Periodic health checks every 5 minutes
- This enables the client to monitor its connection status internally

### Self-Managed Health Checks

`jellyfin-mpv-shim` includes built-in health check functionality that manages connection stability:

- **Built-in Health Check**: Configured via `health_check_interval: 300` in `~/.config/jellyfin-mpv-shim/conf.json`
  - Performs periodic client health checks to the Jellyfin server
  - Should exit with an error code when persistent connection issues are detected
  - Systemd's `Restart = "always"` will automatically restart the service when it exits
  
- **No External Monitoring Needed**: The application manages its own connection health
  - Socket errors that are transient are logged but don't require intervention
  - Persistent connection failures should cause the application to exit, triggering systemd restart
  - External log monitoring is unnecessary as the application handles this internally

### Service Restart Policy (Already Implemented)

The systemd service configuration includes automatic recovery:
- Service restarts automatically on exit
- 5-second delay prevents restart loops
- Handles both normal exits and errors
- Works in conjunction with the health monitoring service

### Manual Service Restart

If issues persist, manually restart the service:
```bash
systemctl --user restart jellyfin-mpv-shim
```

### Temporary Workaround

If websocket errors cause functional issues, you can:
1. Stop the service temporarily
2. Use alternative Jellyfin clients (web UI, mobile apps)
3. Report the issue to Jellyfin with detailed logs

## Reporting Issues

If the problem persists and affects functionality:

1. **Collect Logs:**
   - Client logs: `journalctl --user -u jellyfin-mpv-shim > jellyfin-client.log`
   - Server logs: Check Jellyfin server logs

2. **Document Environment:**
   - Jellyfin server version
   - jellyfin-mpv-shim version
   - Network setup (VPN, reverse proxy, etc.)
   - Hardware transcoding settings

3. **Report to Jellyfin:**
   - **Server Issues**: https://github.com/jellyfin/jellyfin/issues
   - **Client Issues**: https://github.com/jellyfin/jellyfin-mpv-shim/issues
   - **Community Forum**: https://forum.jellyfin.org/

## Related Resources

- **Jellyfin Server Issue #12090**: https://github.com/jellyfin/jellyfin/issues/12090
- **Jellyfin Server Issue #3081**: https://github.com/jellyfin/jellyfin/issues/3081
- **Community Forum Discussion**: https://forum.jellyfin.org/t-websocket-unhandeled-exception
- **jellyfin-mpv-shim Repository**: https://github.com/jellyfin/jellyfin-mpv-shim
- **jellyfin-apiclient-python**: https://github.com/jellyfin/jellyfin-apiclient-python

## Conclusion

The "socket is closed" errors are a **known issue in the Jellyfin ecosystem**, not specific to this configuration. The current systemd service configuration with automatic restart should handle transient connection issues. If errors are non-fatal and don't impact functionality, they can be safely monitored. If functionality is affected, follow the mitigation steps above and consider reporting the issue to the Jellyfin project.

