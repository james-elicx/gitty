//
//  GittyApp.swift
//  Gitty
//
//  Created by James on 02/01/2026.
//

import Combine
import SwiftUI

@main
struct GittyApp: App {
  @StateObject private var notificationBadge = NotificationBadge()
  @StateObject private var backgroundRefreshManager: BackgroundRefreshManager

  init() {
    let badge = NotificationBadge()
    _notificationBadge = StateObject(wrappedValue: badge)
    _backgroundRefreshManager = StateObject(
      wrappedValue: BackgroundRefreshManager(notificationBadge: badge))
  }

  var body: some Scene {
    MenuBarExtra {
      ContentView()
        .environmentObject(notificationBadge)
        .environmentObject(backgroundRefreshManager)
    } label: {
      HStack(spacing: 6) {
        Image("GitIcon")
          .renderingMode(.template)
          .resizable()
          .scaledToFit()
          .frame(width: 14, height: 14)
        if notificationBadge.unreadCount > 0 {
          Text("\(notificationBadge.unreadCount)")
            .font(.caption2)
            .fontWeight(.bold)
        }
      }
    }
    .menuBarExtraStyle(.window)
  }
}

class NotificationBadge: ObservableObject {
  @Published var unreadCount: Int = 0
}

class BackgroundRefreshManager: ObservableObject {
  @Published var shouldRefresh: Bool = false
  @Published var cachedNotifications: [GitHubNotification] = []
  @Published var refreshInterval: TimeInterval = 60.0
  private var refreshTimer: Timer?
  private var cancellables = Set<AnyCancellable>()
  private weak var notificationBadge: NotificationBadge?

  init(notificationBadge: NotificationBadge) {
    self.notificationBadge = notificationBadge
    // Load saved refresh interval
    self.refreshInterval = PersistenceManager.shared.getRefreshInterval()
    // Load cached notifications on init
    loadCachedNotifications()
    startAutoRefresh()
    // Update badge count with cached notifications
    updateBadgeCount()
  }

  deinit {
    stopAutoRefresh()
  }

  func startAutoRefresh() {
    // Stop any existing timer first
    stopAutoRefresh()

    // Start new timer with current interval
    refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) {
      [weak self] _ in
      self?.performBackgroundRefresh()
    }
    // Keep the timer running even when menu is closed
    if let timer = refreshTimer {
      RunLoop.main.add(timer, forMode: .common)
    }
    print("⏰ Auto-refresh started with interval: \(refreshInterval)s")
  }

  func stopAutoRefresh() {
    refreshTimer?.invalidate()
    refreshTimer = nil
  }

  func triggerRefresh() {
    shouldRefresh.toggle()
  }

  func setRefreshInterval(_ interval: TimeInterval) {
    self.refreshInterval = interval
    PersistenceManager.shared.setRefreshInterval(interval)
    // Restart timer with new interval
    startAutoRefresh()
    print("⏰ Refresh interval updated to: \(interval)s")
  }

  private func loadCachedNotifications() {
    if let cached = PersistenceManager.shared.getCachedNotificationsFiltered() {
      self.cachedNotifications = cached
    }
  }

  private func performBackgroundRefresh() {
    // Get the token from keychain
    guard let token = KeychainManager.shared.getToken() else {
      return
    }

    Task {
      do {
        let fetchedNotifications = try await GitHubAPI.shared.fetchNotifications(token: token)

        await MainActor.run {
          // Cache the notifications
          PersistenceManager.shared.cacheNotifications(fetchedNotifications)

          // Update cached notifications
          self.cachedNotifications =
            PersistenceManager.shared.getCachedNotificationsFiltered() ?? []

          // Update badge count
          self.updateBadgeCount()

          // Trigger refresh in UI
          self.triggerRefresh()

          print("🔄 Background refresh completed: \(fetchedNotifications.count) notifications")
        }
      } catch {
        print("❌ Background refresh failed: \(error.localizedDescription)")
      }
    }
  }

  func updateNotifications(_ notifications: [GitHubNotification]) {
    self.cachedNotifications = notifications
    updateBadgeCount()
  }

  private func updateBadgeCount() {
    let unreadCount = cachedNotifications.filter { $0.unread }.count
    notificationBadge?.unreadCount = unreadCount
    print("📊 Updated badge count: \(unreadCount)")
  }
}
