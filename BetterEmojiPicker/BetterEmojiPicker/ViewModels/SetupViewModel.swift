//
//  SetupViewModel.swift
//  BetterEmojiPicker
//
//  Manages state for the first-run setup wizard.
//

import Foundation
import SwiftUI
import ServiceManagement

/// The steps in the setup wizard flow.
enum SetupStep: Int, CaseIterable {
    case welcome
    case accessibility
    case shortcut
    case launchAtLogin
    case complete
}

/// Manages state and actions for the setup wizard.
@MainActor
final class SetupViewModel: ObservableObject {

    // MARK: - Published State

    @Published var currentStep: SetupStep = .welcome {
        didSet {
            // Start/stop permission polling based on step
            if currentStep == .accessibility {
                startPermissionPolling()
            } else {
                stopPermissionPolling()
            }
        }
    }
    @Published var hasAccessibilityPermission: Bool = false
    @Published var launchAtLoginEnabled: Bool = false

    // MARK: - Private State

    private var permissionCheckTimer: Timer?

    // MARK: - UserDefaults Keys

    private static let hasCompletedSetupKey = "hasCompletedSetup"

    // MARK: - Computed Properties

    var isFirstStep: Bool {
        currentStep == .welcome
    }

    var isLastStep: Bool {
        currentStep == .complete
    }

    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .accessibility:
            // Allow proceeding even without permission, but recommend it
            return true
        case .shortcut:
            return true
        case .launchAtLogin:
            return true
        case .complete:
            return true
        }
    }

    // MARK: - Class Methods

    /// Returns true if the user has already completed setup.
    static func hasCompletedSetup() -> Bool {
        UserDefaults.standard.bool(forKey: hasCompletedSetupKey)
    }

    /// Marks setup as completed.
    static func markSetupCompleted() {
        UserDefaults.standard.set(true, forKey: hasCompletedSetupKey)
    }

    /// Resets setup state (for debugging or re-running setup).
    static func resetSetup() {
        UserDefaults.standard.set(false, forKey: hasCompletedSetupKey)
    }

    // MARK: - Actions

    func checkPermissions() {
        hasAccessibilityPermission = PasteService.shared.hasPermission()
    }

    func requestAccessibilityPermission() {
        PasteService.shared.requestPermission()

        // Check again after delay (permission is granted async)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.checkPermissions()
        }
    }

    func nextStep() {
        guard let currentIndex = SetupStep.allCases.firstIndex(of: currentStep),
              currentIndex < SetupStep.allCases.count - 1 else {
            return
        }
        currentStep = SetupStep.allCases[currentIndex + 1]
    }

    func previousStep() {
        guard let currentIndex = SetupStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else {
            return
        }
        currentStep = SetupStep.allCases[currentIndex - 1]
    }

    func completeSetup() {
        SetupViewModel.markSetupCompleted()
    }

    func toggleLaunchAtLogin() {
        launchAtLoginEnabled.toggle()
        updateLaunchAtLogin()
    }

    private func updateLaunchAtLogin() {
        // Use SMAppService for modern macOS launch-at-login
        if #available(macOS 13.0, *) {
            do {
                if launchAtLoginEnabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("⚠️ BEP: Failed to update launch-at-login: \(error)")
            }
        }
    }

    func loadLaunchAtLoginState() {
        if #available(macOS 13.0, *) {
            launchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
        }
    }

    // MARK: - Permission Polling

    /// Starts polling for accessibility permission changes.
    /// Used on the accessibility step to provide immediate feedback.
    private func startPermissionPolling() {
        // Stop any existing timer first
        stopPermissionPolling()

        // Poll every 0.5 seconds
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPermissions()

                // Stop polling once permission is granted
                if self?.hasAccessibilityPermission == true {
                    self?.stopPermissionPolling()
                }
            }
        }
    }

    /// Stops polling for accessibility permission.
    private func stopPermissionPolling() {
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }

    deinit {
        permissionCheckTimer?.invalidate()
    }
}
