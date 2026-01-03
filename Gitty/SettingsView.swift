//
//  SettingsView.swift
//  Gitty
//
//  Created by Assistant on 03/01/2026.
//

import ServiceManagement
import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject var backgroundRefreshManager: BackgroundRefreshManager
  @State private var organizations: [String] = []
  @State private var hiddenOrganizations: Set<String> = []
  @State private var launchAtLogin: Bool = false
  @State private var refreshInterval: TimeInterval = 60.0

  var body: some View {
    VStack(spacing: 20) {
      HStack {
        Text("Settings")
          .font(.title2)
          .fontWeight(.bold)

        Spacer()

        Button(action: {
          dismiss()
        }) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
      }

      Divider()

      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          // General Section
          VStack(alignment: .leading, spacing: 12) {
            Text("General")
              .font(.headline)

            Toggle("Launch at Login", isOn: $launchAtLogin)
              .toggleStyle(.switch)
              .onChange(of: launchAtLogin) { newValue in
                setLaunchAtLogin(enabled: newValue)
              }

            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text("Background Refresh Interval")
                Spacer()
                Picker("", selection: $refreshInterval) {
                  Text("30 seconds").tag(30.0)
                  Text("1 minute").tag(60.0)
                  Text("2 minutes").tag(120.0)
                  Text("5 minutes").tag(300.0)
                  Text("10 minutes").tag(600.0)
                  Text("15 minutes").tag(900.0)
                }
                .pickerStyle(.menu)
                .frame(width: 120)
                .onChange(of: refreshInterval) { _, newValue in
                  backgroundRefreshManager.setRefreshInterval(newValue)
                }
              }

              Text("How often to check for new notifications in the background")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          Divider()

          // Organization Filtering Section
          VStack(alignment: .leading, spacing: 12) {
            Text("Organization Filtering")
              .font(.headline)

            Text("Hide notifications from specific organizations")
              .font(.caption)
              .foregroundColor(.secondary)

            if organizations.isEmpty {
              Text("No organizations found in your notifications")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
            } else {
              VStack(alignment: .leading, spacing: 8) {
                ForEach(organizations, id: \.self) { org in
                  HStack {
                    Toggle(
                      isOn: Binding(
                        get: { !hiddenOrganizations.contains(org) },
                        set: { isVisible in
                          if isVisible {
                            hiddenOrganizations.remove(org)
                            PersistenceManager.shared.unhideOrganization(org)
                          } else {
                            hiddenOrganizations.insert(org)
                            PersistenceManager.shared.hideOrganization(org)
                          }
                        }
                      )
                    ) {
                      Text(org)
                        .font(.subheadline)
                    }
                    .toggleStyle(.switch)
                  }
                }
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          Divider()

          // About Section
          VStack(alignment: .leading, spacing: 12) {
            Text("About")
              .font(.headline)

            Text("Gitty - GitHub Notifications")
              .font(.subheadline)
              .foregroundColor(.secondary)

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
            {
              Text("Version \(version) (\(build))")
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
              Text("Version 1.0.0")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          Divider()

          // Actions Section
          VStack(spacing: 12) {
            Button("Clear Done Notifications") {
              PersistenceManager.shared.clearDoneNotifications()
              dismiss()
            }
            .buttonStyle(.borderedProminent)

            Button("Reset Organization Filters") {
              PersistenceManager.shared.clearHiddenOrganizations()
              loadOrganizations()
            }
            .buttonStyle(.bordered)

            Button("Clear All Data & Cache") {
              PersistenceManager.shared.resetAll()
              loadOrganizations()
            }
            .buttonStyle(.bordered)
          }
        }
      }
    }
    .padding()
    .frame(width: 450, height: 500)
    .onAppear {
      loadOrganizations()
      launchAtLogin = isLaunchAtLoginEnabled()
      refreshInterval = backgroundRefreshManager.refreshInterval
    }
  }

  private func isLaunchAtLoginEnabled() -> Bool {
    return SMAppService.mainApp.status == .enabled
  }

  private func setLaunchAtLogin(enabled: Bool) {
    let service = SMAppService.mainApp
    do {
      if enabled {
        try service.register()
        print("✅ Launch at login enabled")
      } else {
        try service.unregister()
        print("❌ Launch at login disabled")
      }
    } catch {
      print("⚠️ Failed to set launch at login: \(error)")
    }
  }

  private func loadOrganizations() {
    // Get all repositories from cached notifications
    if let cachedNotifications = PersistenceManager.shared.getCachedNotifications() {
      let orgSet = Set(
        cachedNotifications.compactMap { notification -> String? in
          let components = notification.repository.split(separator: "/")
          return components.first.map(String.init)
        })
      organizations = orgSet.sorted()
    }

    // Load hidden organizations
    hiddenOrganizations = PersistenceManager.shared.getHiddenOrganizations()
  }
}

#Preview {
  SettingsView()
}
