import SwiftUI

struct DeviceListView: View {
    @ObservedObject private var deviceManager = DeviceManager.shared
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showSubscription = false

    var body: some View {
        NavigationStack {
            Group {
                if deviceManager.isLoading && deviceManager.devices.isEmpty {
                    ProgressView("loading")
                } else {
                    // All users can see device list
                    deviceListView
                }
            }
            .navigationTitle("sync_devices")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if subscriptionManager.isPro {
                            Task {
                                await deviceManager.syncDevices()
                            }
                        } else {
                            showSubscription = true
                        }
                    }) {
                        if deviceManager.isLoading && subscriptionManager.isPro {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: subscriptionManager.isPro ? "arrow.triangle.2.circlepath" : "lock.fill")
                        }
                    }
                    .disabled(deviceManager.isLoading && subscriptionManager.isPro)
                }
            }
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
        }
    }

    private var deviceListView: some View {
        List {
            Section {
                ForEach(deviceManager.devices) { device in
                    DeviceRow(device: device)
                }
                .onDelete(perform: deleteDevices)
            } header: {
                Text(LocalizedStringKey("connected_devices"))
            } footer: {
                if subscriptionManager.isPro {
                    Text(LocalizedStringKey("device_sync_footer"))
                        .font(.caption)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("device_list_free"))
                            .font(.caption)
                        Text(LocalizedStringKey("otp_sync_requires_pro"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .refreshable {
            if subscriptionManager.isPro {
                await deviceManager.syncDevices()
            } else {
                showSubscription = true
            }
        }
    }

    private var proRequiredView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 12) {
                Text("pro_feature")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("device_sync_requires_pro")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button(action: {
                showSubscription = true
            }) {
                Text("upgrade_to_pro")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    private func deleteDevices(at offsets: IndexSet) {
        for index in offsets {
            let device = deviceManager.devices[index]
            if !device.isCurrentDevice {
                deviceManager.removeDevice(device)
            }
        }
    }
}

struct DeviceRow: View {
    let device: SyncDevice

    var body: some View {
        HStack(spacing: 16) {
            // Device Icon
            ZStack {
                Circle()
                    .fill(device.isCurrentDevice ? LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [Color(.systemGray4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                Image(systemName: device.deviceType.iconName)
                    .foregroundStyle(.white)
                    .font(.system(size: 24))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(device.name)
                        .font(.headline)

                    if device.isCurrentDevice {
                        Text("this_device")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                    }
                }

                Text(device.deviceType.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(lastSyncText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var lastSyncText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return String(format: NSLocalizedString("last_sync_time", comment: ""), formatter.localizedString(for: device.lastSyncDate, relativeTo: Date()))
    }
}

#Preview {
    DeviceListView()
}
