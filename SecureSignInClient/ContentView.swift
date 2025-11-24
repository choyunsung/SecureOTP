//
//  ContentView.swift
//  SecureSignInClient
//
//  Created by yunsung on 11/24/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Int = 0

    var body: some View {
        #if os(watchOS)
        watchOSView
        #elseif os(iOS)
        iOSTabView
        #else
        macOSView
        #endif
    }

    // MARK: - iOS TabView

    #if os(iOS)
    private var iOSTabView: some View {
        TabView(selection: $selectedTab) {
            AuthenticatorView()
                .tabItem {
                    Label("Account", systemImage: "person.circle.fill")
                }
                .tag(0)

            OTPServicesView()
                .tabItem {
                    Label("OTP Services", systemImage: "shield.lefthalf.filled")
                }
                .tag(1)
        }
    }
    #endif

    // MARK: - macOS NavigationView

    #if os(macOS)
    private var macOSView: some View {
        NavigationView {
            List {
                NavigationLink(destination: AuthenticatorView()) {
                    Label("My Account", systemImage: "person.circle.fill")
                }
                NavigationLink(destination: OTPServicesView()) {
                    Label("OTP Services", systemImage: "shield.lefthalf.filled")
                }
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)

            // Default view
            AuthenticatorView()
        }
        .frame(minWidth: 800, minHeight: 500)
    }
    #endif

    // MARK: - watchOS Simple List

    #if os(watchOS)
    private var watchOSView: some View {
        List {
            NavigationLink(destination: AuthenticatorView()) {
                Label("Account", systemImage: "person.circle.fill")
            }
            NavigationLink(destination: OTPServicesView()) {
                Label("OTP", systemImage: "shield.lefthalf.filled")
            }
        }
        .navigationTitle("Secure OTP")
    }
    #endif
}
