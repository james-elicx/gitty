//
//  NotificationsView.swift
//  Gitty
//
//  Created by James on 02/01/2026.
//

import SwiftUI

struct NotificationsView: View {
  @ObservedObject var authViewModel: AuthViewModel
  @EnvironmentObject var notificationBadge: NotificationBadge
  @State private var notifications: [GitHubNotification] = []
  @State private var isLoading: Bool = false
  @State private var errorMessage: String?
  @State private var refreshTimer: Timer?
  @State private var hasLoadedOnce: Bool = false
  @State private var selectedRepository: String? = nil
  @State private var showingSettings: Bool = false

  var body: some View {
    VStack(spacing: 16) {
      headerView
        .padding(.horizontal)
        .padding(.top)

      Divider()
        .padding(.horizontal)

      if !notifications.isEmpty {
        repositoryFilterPills
          .padding(.horizontal)
      }

      contentView
    }
    .frame(width: 400, height: 500)
    .onAppear {
      if !hasLoadedOnce {
        // First load: show cache immediately, then fetch with smart pagination
        showCachedNotifications()
        fetchNotifications()
        hasLoadedOnce = true
      } else {
        // Subsequent loads: fetch with date-based pagination
        fetchNotifications()
      }
      startAutoRefresh()
    }
    .onDisappear {
      stopAutoRefresh()
    }
    .onChange(of: showingSettings) { _, newValue in
      if newValue {
        openSettingsWindow()
      }
    }
  }

  // MARK: - View Components

  private var headerView: some View {
    HStack {
      Image(systemName: "bell.fill")
        .font(.title2)
        .foregroundColor(.blue)

      Text("Notifications")
        .font(.title2)
        .fontWeight(.bold)

      Spacer()

      if isLoading && !notifications.isEmpty {
        ProgressView()
          .controlSize(.small)
      } else {
        Button(action: {
          fetchNotifications()
        }) {
          Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.plain)
        .help("Refresh notifications")
      }

      Button(action: {
        showingSettings = true
      }) {
        Image(systemName: "gear")
      }
      .buttonStyle(.plain)
      .help("Settings")

      Button(action: {
        authViewModel.signOut()
      }) {
        Image(systemName: "rectangle.portrait.and.arrow.right")
      }
      .buttonStyle(.plain)
      .help("Sign out")
    }
  }

  private var repositoryFilterPills: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        allRepositoriesPill

        ForEach(uniqueRepositories, id: \.self) { repo in
          repositoryPill(for: repo)
        }
      }
    }
  }

  private var allRepositoriesPill: some View {
    let isSelected = selectedRepository == nil

    return Button(action: {
      selectedRepository = nil
    }) {
      HStack {
        Text("All")
          .font(.caption)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.gray.opacity(isSelected ? 0.15 : 0.05))
      .foregroundColor(.secondary)
      .cornerRadius(8)
    }
    .buttonStyle(PlainButtonStyle())
  }

  private func repositoryPill(for repo: String) -> some View {
    let isSelected = selectedRepository == repo
    let repoName = String(repo.split(separator: "/").last ?? Substring(repo))

    return Button(action: {
      selectedRepository = repo
    }) {
      HStack {
        Text(repoName)
          .font(.caption)
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.gray.opacity(isSelected ? 0.15 : 0.05))
      .foregroundColor(.secondary)
      .cornerRadius(8)
    }
    .buttonStyle(PlainButtonStyle())
  }

  @ViewBuilder
  private var contentView: some View {
    if isLoading && notifications.isEmpty {
      VStack(spacing: 12) {
        ProgressView()
        Text("Loading notifications...")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding()
    } else if let error = errorMessage {
      VStack(spacing: 12) {
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 40))
          .foregroundColor(.orange)

        Text("Error")
          .font(.headline)

        Text(error)
          .font(.subheadline)
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)

        Button("Retry") {
          fetchNotifications()
        }
        .buttonStyle(.borderedProminent)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding()
    } else if notifications.isEmpty && !isLoading {
      VStack(spacing: 12) {
        Image(systemName: "checkmark.circle")
          .font(.system(size: 40))
          .foregroundColor(.green)

        Text("All caught up!")
          .font(.headline)

        Text("You have no notifications")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding()
    } else {
      ScrollView {
        LazyVStack(spacing: 8) {
          ForEach(filteredNotifications) { notification in
            NotificationRow(
              notification: notification,
              onMarkAsDone: { markAsDone(notification: notification) },
              onToggleRead: { toggleReadStatus(notification: notification) },
              onToggleSubscription: { toggleSubscription(notification: notification) }
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
          }
        }
        .animation(.easeInOut(duration: 0.3), value: filteredNotifications)
        .padding(.horizontal)
        .padding(.bottom)
      }
    }
  }

  // MARK: - Computed Properties

  /// Get notifications excluding done ones, sorted by most recent
  private var visibleNotifications: [GitHubNotification] {
    let doneIds = PersistenceManager.shared.getDoneNotificationIds()
    let hiddenOrgs = PersistenceManager.shared.getHiddenOrganizations()

    return
      notifications
      .filter { notification in
        // Filter out done notifications
        if doneIds.contains(notification.id) {
          return false
        }

        // Filter out notifications from hidden organizations
        let organization =
          notification.repository.split(separator: "/").first.map(String.init) ?? ""
        if hiddenOrgs.contains(organization) {
          return false
        }

        return true
      }
      .sorted { $0.updatedAt > $1.updatedAt }
  }

  /// Get unique repositories from visible notifications sorted by most recent notification
  private var uniqueRepositories: [String] {
    // Group notifications by repository and find the most recent for each
    var repoToMostRecent: [String: Date] = [:]

    for notification in visibleNotifications {
      let repo = notification.repository
      let date = notification.updatedAt

      if let existingDate = repoToMostRecent[repo] {
        repoToMostRecent[repo] = max(existingDate, date)
      } else {
        repoToMostRecent[repo] = date
      }
    }

    // Sort repositories by most recent notification date (newest first)
    return repoToMostRecent.sorted { $0.value > $1.value }.map { $0.key }
  }

  /// Filter notifications by selected repository
  private var filteredNotifications: [GitHubNotification] {
    guard let selectedRepo = selectedRepository else {
      return visibleNotifications
    }
    return visibleNotifications.filter { $0.repository == selectedRepo }
  }

  // MARK: - Methods

  private func openSettingsWindow() {
    let settingsView = SettingsView()
    let hostingController = NSHostingController(rootView: settingsView)

    let window = NSWindow(contentViewController: hostingController)
    window.title = "Settings"
    window.styleMask = [.titled, .closable]
    window.setContentSize(NSSize(width: 400, height: 300))
    window.center()
    window.makeKeyAndOrderFront(nil)

    // Keep reference to prevent window from being deallocated
    NSApp.activate(ignoringOtherApps: true)

    showingSettings = false
  }

  private func showCachedNotifications() {
    // Show cached notifications immediately without loading indicator
    if let cached = PersistenceManager.shared.getCachedNotificationsFiltered() {
      self.notifications = cached
      print("💾 Showing \(cached.count) cached notifications")
    }
  }

  private func fetchNotifications() {
    isLoading = true
    errorMessage = nil

    // Use real API or mock data based on preference
    let useMockData = false  // Set to false to use real GitHub API

    if useMockData {
      // Mock data for testing UI
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        self.notifications = [
          GitHubNotification(
            id: "1",
            title: "Bug in login flow",
            repository: "user/awesome-repo",
            type: "Issue",
            updatedAt: Date(),
            number: 42,
            reason: "assign",
            unread: true,
            url: "https://github.com/user/awesome-repo/issues/42",
            repositoryUrl: "https://github.com/user/awesome-repo",
            subscribed: true
          ),
          GitHubNotification(
            id: "2",
            title: "Add dark mode support",
            repository: "user/another-repo",
            type: "PullRequest",
            updatedAt: Date().addingTimeInterval(-3600),
            number: 127,
            reason: "review_requested",
            unread: false,
            url: "https://github.com/user/another-repo/pull/127",
            repositoryUrl: "https://github.com/user/another-repo",
            subscribed: false
          ),
        ]
        self.isLoading = false
      }
    } else {
      // Real GitHub API call
      guard let token = authViewModel.getToken() else {
        errorMessage = "No authentication token found"
        isLoading = false
        return
      }

      Task {
        do {
          let fetchedNotifications = try await GitHubAPI.shared.fetchNotifications(token: token)
          await MainActor.run {
            self.notifications = fetchedNotifications
            self.isLoading = false
            self.updateBadgeCount()
          }
        } catch let error as GitHubAPIError {
          await MainActor.run {
            self.errorMessage = error.errorDescription ?? "Unknown error occurred"
            self.isLoading = false
          }
        } catch {
          await MainActor.run {
            self.errorMessage = "Failed to fetch notifications: \(error.localizedDescription)"
            self.isLoading = false
          }
        }
      }
    }
  }

  private func markAsDone(notification: GitHubNotification) {
    guard let token = authViewModel.getToken() else { return }

    Task {
      do {
        // Call API to mark as done on GitHub first
        try await GitHubAPI.shared.deleteNotification(notificationId: notification.id, token: token)

        // Only mark as done in persistence after API call succeeds
        PersistenceManager.shared.markAsDone(notificationId: notification.id)

        await MainActor.run {
          // Remove from list with animation
          withAnimation(.easeInOut(duration: 0.3)) {
            notifications.removeAll { $0.id == notification.id }
          }
          updateBadgeCount()
        }
      } catch {
        print("Failed to mark as done: \(error)")
      }
    }
  }

  private func toggleReadStatus(notification: GitHubNotification) {
    guard let token = authViewModel.getToken() else { return }

    if notification.unread {
      Task {
        do {
          print("Marking notification as read: \(notification.id)")
          try await GitHubAPI.shared.markAsRead(notificationId: notification.id, token: token)
          print("Successfully marked as read on API")
          await MainActor.run {
            // Update notification to read with animation
            withAnimation(.easeInOut(duration: 0.3)) {
              if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                print("Updated UI for notification at index \(index)")
                notifications[index] = GitHubNotification(
                  id: notification.id,
                  title: notification.title,
                  repository: notification.repository,
                  type: notification.type,
                  updatedAt: notification.updatedAt,
                  number: notification.number,
                  reason: notification.reason,
                  unread: false,
                  url: notification.url,
                  repositoryUrl: notification.repositoryUrl,
                  subscribed: notification.subscribed
                )
                updateBadgeCount()
              } else {
                print("Warning: Could not find notification in array after marking as read")
              }
            }
          }
        } catch {
          print("Failed to mark as read: \(error)")
        }
      }
    } else {
      print("Notification is already marked as read, skipping")
    }
  }

  private func toggleSubscription(notification: GitHubNotification) {
    guard let token = authViewModel.getToken() else { return }

    Task {
      do {
        // Toggle subscription
        try await GitHubAPI.shared.setThreadSubscription(
          threadId: notification.id, subscribed: !notification.subscribed, token: token)

        await MainActor.run {
          // Update notification subscribed status with animation
          withAnimation(.easeInOut(duration: 0.3)) {
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
              notifications[index] = GitHubNotification(
                id: notification.id,
                title: notification.title,
                repository: notification.repository,
                type: notification.type,
                updatedAt: notification.updatedAt,
                number: notification.number,
                reason: notification.reason,
                unread: notification.unread,
                url: notification.url,
                repositoryUrl: notification.repositoryUrl,
                subscribed: !notification.subscribed
              )
            }
          }
        }
      } catch let error as GitHubAPIError {
        print("Failed to toggle subscription: \(error.errorDescription ?? "Unknown error")")
        // 404 means the thread doesn't support subscriptions or doesn't exist
        if case .httpError(let statusCode) = error, statusCode == 404 {
          print("Note: This notification thread doesn't support subscription management")
        }
      } catch {
        print("Failed to toggle subscription: \(error.localizedDescription)")
      }
    }
  }

  private func startAutoRefresh() {
    // Refresh every 60 seconds
    refreshTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
      fetchNotifications()
    }
  }

  private func stopAutoRefresh() {
    refreshTimer?.invalidate()
    refreshTimer = nil
  }

  private func updateBadgeCount() {
    let unreadCount = visibleNotifications.filter { $0.unread }.count
    notificationBadge.unreadCount = unreadCount
  }
}

// Model for GitHub notifications
struct GitHubNotification: Identifiable, Equatable, Codable {
  let id: String
  let title: String
  let repository: String
  let type: String
  let updatedAt: Date
  let number: Int?
  let reason: String?
  let unread: Bool
  let url: String?
  let repositoryUrl: String?
  let subscribed: Bool

  var icon: String {
    switch type {
    case "Issue":
      return "exclamationmark.circle.fill"
    case "PullRequest":
      return "arrow.triangle.pull"
    case "Commit":
      return "arrow.turn.up.right"
    case "Release":
      return "tag.fill"
    case "CheckSuite":
      return "checkmark.circle.fill"
    case "Discussion":
      return "bubble.left.and.bubble.right.fill"
    default:
      return "bell.fill"
    }
  }

  var shouldShowNumber: Bool {
    return type == "Issue" || type == "PullRequest"
  }

  var supportsSubscription: Bool {
    // Only Issues and PullRequests reliably support subscriptions
    return type == "Issue" || type == "PullRequest"
  }

  var timeAgo: String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: updatedAt, relativeTo: Date())
  }
}

// Row component for each notification
struct NotificationRow: View {
  let notification: GitHubNotification
  let onMarkAsDone: () -> Void
  let onToggleRead: () -> Void
  let onToggleSubscription: () -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      Image(systemName: notification.icon)
        .font(.title3)
        .foregroundColor(.blue)
        .frame(width: 20, alignment: .center)
        .frame(maxHeight: .infinity, alignment: .center)

      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Button(action: {
            if let urlString = notification.url, let url = URL(string: urlString) {
              NSWorkspace.shared.open(url)
            }
          }) {
            HStack(spacing: 0) {
              if notification.shouldShowNumber, let number = notification.number {
                Text("#\(number)  ")
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .baselineOffset(-0.5)
              }

              Text(notification.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)
            }
          }
          .buttonStyle(.plain)
          .disabled(notification.url == nil)
          .onHover { isHovering in
            if isHovering && notification.url != nil {
              NSCursor.pointingHand.push()
            } else {
              NSCursor.pop()
            }
          }

          Spacer()

          // Action buttons
          HStack(spacing: 6) {
            // Mark as done
            Button(action: {
              onMarkAsDone()
            }) {
              Image(systemName: "checkmark")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Mark as done")
            .onHover { isHovering in
              if isHovering {
                NSCursor.pointingHand.push()
              } else {
                NSCursor.pop()
              }
            }

            // Mark as read (only show for unread notifications)
            if notification.unread {
              Button(action: {
                onToggleRead()
              }) {
                Image(systemName: "eye")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              .buttonStyle(.plain)
              .help("Mark as read")
              .onHover { isHovering in
                if isHovering {
                  NSCursor.pointingHand.push()
                } else {
                  NSCursor.pop()
                }
              }
            }

            // Subscribe/unsubscribe (only for types that support it)
            if notification.supportsSubscription {
              Button(action: {
                onToggleSubscription()
              }) {
                Image(systemName: notification.subscribed ? "bell" : "bell.slash")
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
              .buttonStyle(.plain)
              .help("Toggle subscription")
              .onHover { isHovering in
                if isHovering {
                  NSCursor.pointingHand.push()
                } else {
                  NSCursor.pop()
                }
              }
            }
          }
        }

        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Button(action: {
            if let urlString = notification.repositoryUrl, let url = URL(string: urlString) {
              NSWorkspace.shared.open(url)
            }
          }) {
            Text(notification.repository)
              .font(.caption)
              .foregroundColor(.secondary)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          .buttonStyle(.plain)
          .disabled(notification.repositoryUrl == nil)
          .onHover { isHovering in
            if isHovering && notification.repositoryUrl != nil {
              NSCursor.pointingHand.push()
            } else {
              NSCursor.pop()
            }
          }

          if let reason = notification.reason {
            Text("•")
              .font(.caption)
              .foregroundColor(.secondary)

            Text(reason.replacingOccurrences(of: "_", with: " "))
              .font(.caption)
              .foregroundColor(.secondary)
          }

          Spacer()

          Text(notification.timeAgo)
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding(8)
    .background(Color.gray.opacity(0.05))
    .cornerRadius(8)
    .opacity(notification.unread ? 1.0 : 0.6)
  }
}

#Preview {
  let authViewModel = AuthViewModel()
  NotificationsView(authViewModel: authViewModel)
    .environmentObject(NotificationBadge())
}
