//
// Copyright © 2021 osy. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import SwiftUI

struct VMDrivesSettingsView<Drive: UTMConfigurationDrive>: View {
    @Binding var drives: [Drive]
    let template: Drive
    @State var newDrive: Drive
    @EnvironmentObject private var data: UTMData
    @State private var newDrivePopover: Bool = false
    @State private var importDrivePresented: Bool = false
    @State private var requestDriveDelete: Drive?
    
    init(drives: Binding<[Drive]>, template: Drive) {
        self._drives = drives
        self._newDrive = State<Drive>(initialValue: template)
        self.template = template
    }

    var body: some View {
        ForEach($drives) { $drive in
            let driveIndex = drives.firstIndex(of: drive)!
            NavigationLink {
                DriveDetailsView(config: $drive, requestDriveDelete: $requestDriveDelete)
                    .scrollable()
                    .settingsToolbar {
                        ToolbarItem(placement: .destructiveAction) {
                            Button("Delete") {
                                requestDriveDelete = drive
                            }
                        }
                    }
            } label: {
                Label(label(for: drive), systemImage: "externaldrive")
            }.contextMenu {
                DestructiveButton("Delete") {
                    requestDriveDelete = drive
                }
                if driveIndex != 0 {
                    Button {
                        drives.move(fromOffsets: IndexSet(integer: driveIndex), toOffset: driveIndex - 1)
                    } label: {
                        Label("Move Up", systemImage: "chevron.up")
                    }
                }
                if driveIndex != drives.count - 1 {
                    Button {
                        drives.move(fromOffsets: IndexSet(integer: driveIndex), toOffset: driveIndex + 2)
                    } label: {
                        Label("Move Down", systemImage: "chevron.down")
                    }
                }
            }
        }.onMove { offsets, index in
            drives.move(fromOffsets: offsets, toOffset: index)
        }
        .alert(item: $requestDriveDelete) { drive in
            Alert(title: Text("Are you sure you want to permanently delete this disk image?"), primaryButton: .destructive(Text("Delete")) {
                drives.removeAll(where: { $0 == drive })
            }, secondaryButton: .cancel())
        }
        Button {
            newDrivePopover.toggle()
        } label: {
            Label("New…", systemImage: "externaldrive.badge.plus")
        }
        .buttonStyle(.link)
        .help("Add a new drive.")
        .fileImporter(isPresented: $importDrivePresented, allowedContentTypes: [.item], onCompletion: importDrive)
        .onChange(of: newDrivePopover, perform: { showPopover in
            if showPopover {
                newDrive = template.clone()
            }
        })
        .popover(isPresented: $newDrivePopover, arrowEdge: .top) {
            VStack {
                // Ugly hack to coerce generic type to one of two binding types
                if newDrive is UTMQemuConfigurationDrive {
                    VMConfigDriveCreateView(config: $newDrive as Any as! Binding<UTMQemuConfigurationDrive>)
                } else if newDrive is UTMAppleConfigurationDrive {
                    VMConfigAppleDriveCreateView(config: $newDrive as Any as! Binding<UTMAppleConfigurationDrive>)
                } else {
                    fatalError("Unsupported drive type")
                }
                HStack {
                    Spacer()
                    Button(action: { importDrivePresented.toggle() }, label: {
                        if newDrive.isExternal {
                            Text("Browse…")
                        } else {
                            Text("Import…")
                        }
                    }).help("Select an existing disk image.")
                    Button(action: { addNewDrive(newDrive) }, label: {
                        Text("Create")
                    }).help("Create an empty drive.")
                }
            }.padding()
        }
    }
    
    private func label(for drive: Drive) -> String {
        if let qemuDrive = drive as? UTMQemuConfigurationDrive {
            if qemuDrive.interface == .none && qemuDrive.imageName == QEMUPackageFileName.efiVariables.rawValue {
                return NSLocalizedString("EFI Variables", comment: "VMDrivesSettingsView")
            } else {
                return String.localizedStringWithFormat(NSLocalizedString("%@ Drive", comment: "VMDrivesSettingsView"), qemuDrive.interface.prettyValue)
            }
        } else if let appleDrive = drive as? UTMAppleConfigurationDrive {
            return String.localizedStringWithFormat(NSLocalizedString("%@ Image", comment: "VMDrivesSettingsView"), appleDrive.sizeString)
        } else {
            fatalError("Unsupported drive type.")
        }
    }

    private func importDrive(result: Result<URL, Error>) {
        var drive = newDrive
        data.busyWorkAsync {
            switch result {
            case .success(let url):
                await MainActor.run {
                    drive.imageURL = url
                    drives.append(drive)
                }
                break
            case .failure(let err):
                throw err
            }
        }
    }

    private func addNewDrive(_ newDrive: Drive) {
        newDrivePopover = false // hide popover
        data.busyWorkAsync {
            DispatchQueue.main.async {
                drives.append(newDrive)
            }
        }
    }
}

private struct DriveDetailsView<Drive: UTMConfigurationDrive>: View {
    @Binding var config: Drive
    @Binding var requestDriveDelete: Drive?
    
    var body: some View {
        if config is UTMQemuConfigurationDrive {
            VMConfigDriveDetailsView(config: $config as Any as! Binding<UTMQemuConfigurationDrive>, requestDriveDelete: $requestDriveDelete as Any as! Binding<UTMQemuConfigurationDrive?>)
        } else if config is UTMAppleConfigurationDrive {
            VMConfigAppleDriveDetailsView(config: $config as Any as! Binding<UTMAppleConfigurationDrive>, requestDriveDelete: $requestDriveDelete as Any as! Binding<UTMAppleConfigurationDrive?>)
        } else {
            fatalError("Unsupported drive type.")
        }
    }
}
