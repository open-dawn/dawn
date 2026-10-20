//
//  DawnColors.swift
//  dawn
//
//  Created by Rafael Venetikides on 19/10/26.
//

import SwiftUI

public enum DawnColors {
    public static let contextCardBackground = Color.black.opacity(0.25)

    public static let contextCardHoveredBackground = Color.black.opacity(0.34)

    public static let contextCardBorder = Color.white.opacity(0.04)

    public static let contextCardHoveredBorder = Color.white.opacity(0.10)
    
    public static let primaryBackground = Color(red: 0x1f/0xff, green: 0x1f/0xff, blue: 0x1f/0xff) // #1f1f1f
    
    public static let secondaryBackground = Color(red: 0x27/0xff, green: 0x27/0xff, blue: 0x27/0xff) // #272727
    
    public static let primaryForeground = Color(red: 0xff/0xff, green: 0xff/0xff, blue: 0xff/0xff) // #ffffff
    
    public static let dangerBackground = Color.red.opacity(0.3)
    
    public static let dangerForeground = Color.red
    
    public static let warningBackground = Color.yellow.opacity(0.3)
    
    public static let warningForeground = Color.yellow
}
