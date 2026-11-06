//
//  DawnBrand+Previews.swift
//  dawn
//
//  Created by Rafael Venetikides on 23/10/26.
//

#if DEBUG

import SwiftUI

#Preview("DAWN Brand") {
    VStack(spacing: 24) {
        DawnBrand()

        DawnBrand(style: .compact)
    }
    .padding()
    .background(.regularMaterial)
    .preferredColorScheme(.dark)
}

#endif
