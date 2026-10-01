//
//  MultitouchSupportHapticsProvider.swift
//  pineapplewm
//
//  Created by Longhi on 29/09/26.
//

import CoreFoundation
import Darwin
import Foundation
import dawnLogging

/// Drives the trackpad actuator through Apple's private MultitouchSupport framework.
///
/// The framework is loaded dynamically so unsupported systems degrade to a no-op.
final class MultitouchSupportHapticsProvider: HapticsProvider, @unchecked Sendable {
    static let shared = MultitouchSupportHapticsProvider()

    private let runtime: MultitouchSupportRuntime?

    init() {
        runtime = MultitouchSupportRuntime()
    }

    func perform(_ pattern: HapticPattern) {
        runtime?.perform(waveform: pattern.waveform)
    }
}

private extension HapticPattern {
    var waveform: Int32 {
        switch self {
        case .weakClick:
            1
        case .strongClick:
            2
        case .buzz:
            3
        case .lightTap:
            4
        case .mediumTap:
            5
        case .strongTap:
            6
        case .softThud:
            15
        case .strongThud:
            16
        }
    }
}

private final class MultitouchSupportRuntime: @unchecked Sendable {
    private typealias DeviceCreateList = @convention(c) () -> UnsafeRawPointer?
    private typealias ActuatorCreate = @convention(c) (UInt64) -> UnsafeRawPointer?
    private typealias ActuatorOpen = @convention(c) (UnsafeRawPointer, UInt32) -> Int32
    private typealias ActuatorClose = @convention(c) (UnsafeRawPointer) -> Int32
    private typealias ActuatorActuate = @convention(c) (
        UnsafeRawPointer,
        Int32,
        UInt32,
        UInt32,
        UInt32
    ) -> Int32

    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
    private static let deviceIDOffset = 64
    private static let success: Int32 = 0

    private let handle: UnsafeMutableRawPointer
    private let actuatorCreate: ActuatorCreate
    private let actuatorOpen: ActuatorOpen
    private let actuatorClose: ActuatorClose
    private let actuatorActuate: ActuatorActuate
    private let deviceID: UInt64
    private let lock = NSLock()

    init?() {
        guard let handle = dlopen(Self.frameworkPath, RTLD_LAZY | RTLD_LOCAL) else {
            let message: String
            if let error = dlerror() {
                message = String(cString: error)
            } else {
                message = "Unknown error"
            }
            #log(
                "Failed to load MultitouchSupport: \(message)",
                level: .error,
                category: .userInterface
            )
            return nil
        }

        guard
            let deviceCreateList = Self.load(
                "MTDeviceCreateList",
                from: handle,
                as: DeviceCreateList.self
            ),
            let actuatorCreate = Self.load(
                "MTActuatorCreateFromDeviceID",
                from: handle,
                as: ActuatorCreate.self
            ),
            let actuatorOpen = Self.load(
                "MTActuatorOpen",
                from: handle,
                as: ActuatorOpen.self
            ),
            let actuatorClose = Self.load(
                "MTActuatorClose",
                from: handle,
                as: ActuatorClose.self
            ),
            let actuatorActuate = Self.load(
                "MTActuatorActuate",
                from: handle,
                as: ActuatorActuate.self
            )
        else {
            dlclose(handle)
            #log(
                "MultitouchSupport is missing one or more actuator symbols",
                level: .error,
                category: .userInterface
            )
            return nil
        }

        guard let deviceID = Self.findHapticDevice(
            createList: deviceCreateList,
            createActuator: actuatorCreate,
            openActuator: actuatorOpen,
            closeActuator: actuatorClose
        ) else {
            dlclose(handle)
            #log(
                "No haptic-capable multitouch device was found",
                level: .error,
                category: .userInterface
            )
            return nil
        }

        self.handle = handle
        self.actuatorCreate = actuatorCreate
        self.actuatorOpen = actuatorOpen
        self.actuatorClose = actuatorClose
        self.actuatorActuate = actuatorActuate
        self.deviceID = deviceID
    }

    deinit {
        dlclose(handle)
    }

    func perform(waveform: Int32) {
        lock.lock()
        defer { lock.unlock() }

        guard let actuator = actuatorCreate(deviceID) else { return }
        defer { Self.release(actuator) }

        guard actuatorOpen(actuator, 0) == Self.success else { return }
        defer { _ = actuatorClose(actuator) }

        _ = actuatorActuate(actuator, waveform, 0, 0, 0)
    }

    private static func findHapticDevice(
        createList: DeviceCreateList,
        createActuator: ActuatorCreate,
        openActuator: ActuatorOpen,
        closeActuator: ActuatorClose
    ) -> UInt64? {
        guard let devicesPointer = createList() else { return nil }
        let devices = Unmanaged<CFArray>
            .fromOpaque(devicesPointer)
            .takeRetainedValue()

        for index in 0..<CFArrayGetCount(devices) {
            guard let device = CFArrayGetValueAtIndex(devices, index) else {
                continue
            }

            var deviceID: UInt64 = 0
            memcpy(
                &deviceID,
                device.advanced(by: deviceIDOffset),
                MemoryLayout<UInt64>.size
            )

            guard let actuator = createActuator(deviceID) else { continue }
            defer { release(actuator) }

            guard openActuator(actuator, 0) == success else { continue }
            _ = closeActuator(actuator)
            return deviceID
        }

        return nil
    }

    private static func load<Function>(
        _ symbol: String,
        from handle: UnsafeMutableRawPointer,
        as type: Function.Type
    ) -> Function? {
        guard let address = dlsym(handle, symbol) else { return nil }
        return unsafeBitCast(address, to: type)
    }

    private static func release(_ object: UnsafeRawPointer) {
        Unmanaged<AnyObject>.fromOpaque(object).release()
    }
}
