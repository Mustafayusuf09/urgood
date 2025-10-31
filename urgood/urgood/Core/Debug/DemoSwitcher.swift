//
//  DemoSwitcher.swift
//  urgood
//
//  Debug tool for testing multi-user isolation
//

import SwiftUI
import FirebaseAuth

#if DEBUG
// Demo switcher removed. Keeping an empty placeholder to avoid conditional build errors.
struct DemoSwitcherView: View { var body: some View { EmptyView() } }
struct DemoSwitcherButton: View { var body: some View { EmptyView() } }
extension View { func withDemoSwitcher(authService: UnifiedAuthService, appSession: AppSession) -> some View { self } }
#endif

