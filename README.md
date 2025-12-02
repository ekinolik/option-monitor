# option-monitor

A real-time iOS application for monitoring stock option trading summaries via WebSocket.

## Overview

The iOS app connects to a WebSocket server that streams 1-minute summaries of stock option trading data. When connected, it receives all historical summaries for the current day and continues to receive new summaries as they become available.

## Features

- Real-time WebSocket connection to stream option trading summaries
- Display 1-minute summaries in a scrollable list
- Tap any summary to view detailed information
- Configurable WebSocket host and port settings
- Automatic reconnection on connection loss
- Connection status indicator
- Currently monitors AAPL options

## Prerequisites

- Xcode 14.0 or later
- iOS 13.0 or later (for URLSessionWebSocketTask support)
- Swift 5.0 or later
- A running WebSocket server (see [jax-ov](https://github.com/ekinolik/jax-ov) for server implementation)

## Project Structure

```
option-monitor/
├── OptionMonitor/
│   ├── OptionMonitorApp.swift          # App entry point
│   ├── Models/
│   │   └── OptionSummary.swift         # Data model for option summaries
│   ├── Services/
│   │   ├── WebSocketService.swift      # WebSocket connection and message handling
│   │   └── ConfigService.swift         # Configuration management (host/port)
│   └── Views/
│       ├── SummaryListView.swift       # Main list view
│       ├── SummaryDetailView.swift     # Detail view for individual summaries
│       └── SettingsView.swift          # Settings for WebSocket configuration
└── README.md
```

## Setup

### 1. Open in Xcode

1. Open Xcode
2. Select "File" → "Open" and navigate to the `OptionMonitor` directory
3. If there's no Xcode project file, you'll need to create one:
   - Select "File" → "New" → "Project"
   - Choose "iOS" → "App"
   - Product Name: `OptionMonitor`
   - Interface: SwiftUI
   - Language: Swift
   - Save the project in the workspace directory
   - Move all the Swift files into the project in Xcode

### 2. Configure the Project

1. In Xcode, select your project in the navigator
2. Go to the "Signing & Capabilities" tab
3. Select your development team
4. Ensure the deployment target is iOS 13.0 or later

### 3. Add Files to Xcode Project

If you created a new Xcode project, you need to add the existing Swift files:

1. Right-click on the project in the navigator
2. Select "Add Files to OptionMonitor..."
3. Navigate to and select:
   - `OptionMonitor/Models/OptionSummary.swift`
   - `OptionMonitor/Services/WebSocketService.swift`
   - `OptionMonitor/Services/ConfigService.swift`
   - `OptionMonitor/Views/SummaryListView.swift`
   - `OptionMonitor/Views/SummaryDetailView.swift`
   - `OptionMonitor/Views/SettingsView.swift`
   - `OptionMonitor/OptionMonitorApp.swift`
4. Ensure "Copy items if needed" is checked
5. Click "Add"

### 4. Start the WebSocket Server

Before running the app, ensure the WebSocket server is running. See the [jax-ov repository](https://github.com/ekinolik/jax-ov) for server setup instructions.

The default configuration expects the server at `ws://localhost:8080/analyze`.

### 5. Run the App

1. Select a simulator or connected device
2. Press ⌘R or click the "Run" button
3. The app will automatically connect to the WebSocket server

## Usage

### Main View

The main view displays a list of 1-minute option trading summaries, with the most recent at the top. Each summary shows:

- Time period (start → end)
- Total premium traded
- Call/Put ratio
- Call and Put volumes

### Connection Status

A status bar at the top shows the current connection status:
- 🟢 Green: Connected
- 🟡 Yellow: Connecting
- ⚪ Gray: Disconnected
- 🔴 Red: Error

### Viewing Details

Tap any summary in the list to view detailed information including:
- Full time period with dates
- Breakdown of call and put premiums
- Volume breakdown
- Visual call/put ratio indicator

### Configuring Settings

1. Tap the gear icon (⚙️) in the top-right corner
2. Enter the WebSocket server host and port
3. Tap "Save" to update the configuration
4. The connection will automatically reconnect with the new settings

Default settings:
- Host: `localhost`
- Port: `8080`

## Data Format

The app receives JSON objects in JSONL format (one JSON object per message). Each summary contains:

```json
{
  "period_start": "2025-12-02T08:48:00-08:00",
  "period_end": "2025-12-02T08:49:00-08:00",
  "call_premium": 1158667.03,
  "put_premium": 72771,
  "total_premium": 1231438.03,
  "call_put_ratio": 15.922098500776409,
  "call_volume": 2156,
  "put_volume": 363
}
```

## Architecture

The app follows the MVVM (Model-View-ViewModel) pattern:

- **Models**: `OptionSummary` - Represents the data structure
- **Services**: 
  - `WebSocketService` - Manages WebSocket connection and message parsing
  - `ConfigService` - Manages configuration persistence
- **Views**: SwiftUI views for displaying data and handling user interaction

## Technical Details

- **Framework**: SwiftUI for UI
- **Networking**: URLSessionWebSocketTask for WebSocket connections
- **Reactive Programming**: Combine framework for data flow
- **Persistence**: UserDefaults for configuration storage
- **Date Parsing**: ISO8601DateFormatter for parsing timestamps with timezones

## Troubleshooting

### Connection Issues

1. **Cannot connect to server**
   - Verify the WebSocket server is running
   - Check the host and port in Settings
   - For iOS Simulator connecting to localhost: Ensure your Mac's firewall allows connections
   - For physical device: Use your Mac's IP address instead of "localhost"

2. **Connection drops frequently**
   - Check network stability
   - Verify server is still running
   - The app will automatically attempt to reconnect

3. **No data appearing**
   - Check connection status indicator
   - Verify the server is sending data
   - Check Xcode console for error messages

### Building Issues

1. **Missing files error**
   - Ensure all Swift files are added to the Xcode project target
   - Check file membership in the project navigator

2. **Swift version errors**
   - Ensure Xcode is up to date
   - Check deployment target is iOS 13.0+

## Future Enhancements

- Support for multiple tickers
- Historical data visualization with charts
- Filtering and sorting options
- Push notifications for significant volume changes
- Additional detail queries when tapping summaries

## License

[Add your license here]

## References

- [jax-ov Server Repository](https://github.com/ekinolik/jax-ov) - WebSocket server implementation
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [URLSessionWebSocketTask Documentation](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask)
