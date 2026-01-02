//
//  ContentView.swift
//  Gitty
//
//  Created by James on 02/01/2026.
//

import SwiftUI

struct ContentView: View {
  @StateObject private var authViewModel = AuthViewModel()

  var body: some View {
    Group {
      if authViewModel.isLoading {
        VStack(spacing: 16) {
          ProgressView()
            .scaleEffect(1.5)
          Text("Loading...")
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .frame(width: 400, height: 500)
      } else if authViewModel.isAuthenticated {
        NotificationsView(authViewModel: authViewModel)
      } else {
        TokenInputView(authViewModel: authViewModel)
      }
    }
  }
}

#Preview {
  ContentView()
}
