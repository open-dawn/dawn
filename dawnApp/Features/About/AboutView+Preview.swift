//
//  AboutView+Preview.swift
//  dawn
//
//  Created by Longhi on 21/10/26.
//

#if DEBUG

import SwiftUI

#Preview {
    AboutView(content: AboutContent.loadRequired())
        .environment(SettingsEventBusService())
}

#endif
