//
//  ContextCreationConfirmationView+Previews.swift
//  dawn
//
//  Created by Rafael Venetikides on 21/10/26.
//

#if DEBUG

import SwiftUI

#Preview("Creation confirmation") {
    ContextCreationConfirmationView(
        onFinishAndSwitch: {},
        onFinish: {}
    )
    .padding(16)
    .frame(width: 320)
    .background(.regularMaterial)
    .preferredColorScheme(.dark)
}

#endif
