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

  var body: some Scene {
    MenuBarExtra {
      ContentView()
        .environmentObject(notificationBadge)
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
