//
// Copyright © 2023 osy. All rights reserved.
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

import QEMUKitInternal
#if !WITH_USB
import CocoaSpiceNoUsb
#else
import CocoaSpice
#endif

@objc class UTMQemuPort: NSObject, QEMUPort {
    var readDataHandler: readDataHandler_t? {
        didSet {
            updateDelegate()
        }
    }
    
    var errorHandler: errorHandler_t? {
        didSet {
            updateDelegate()
        }
    }
    
    var disconnectHandler: disconnectHandler_t? {
        didSet {
            updateDelegate()
        }
    }
    
    var isOpen: Bool = true
    
    private let port: CSPort
    
    func write(_ data: Data) {
        port.write(data)
    }
    
    @objc init(from port: CSPort) {
        self.port = port
        super.init()
        port.delegate = self
    }
    
    /// We defer setting of delegate to after `readDataHandler` is set in order to handle cached data.
    private func updateDelegate() {
        if readDataHandler != nil || errorHandler != nil || disconnectHandler != nil {
            port.delegate = self
        } else {
            port.delegate = nil
        }
    }
}

extension UTMQemuPort: CSPortDelegate {
    func portDidDisconect(_ port: CSPort) {
        isOpen = false
        disconnectHandler?()
    }
    
    func port(_ port: CSPort, didError error: String) {
        errorHandler?(error)
    }
    
    func port(_ port: CSPort, didRecieveData data: Data) {
        readDataHandler?(data)
    }
}
