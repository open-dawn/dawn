//
//  DButton.swift
//  dawn
//
//  Created by Longhi on 20/10/26.
//

import SwiftUI

struct DButton<Leading: View, Content: View, Trailing: View>: View {
    let style: DButtonStyle
    let action: () -> Void
    let leading: Leading
    let content: Content
    let trailing: Trailing
    
    init(
        style: DButtonStyle = .primary,
        action: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content = {EmptyView()},
        @ViewBuilder leading: () -> Leading = {EmptyView()},
        @ViewBuilder trailing: () -> Trailing = {EmptyView()}
    ) {
        self.style = style
        self.action = action
        self.leading = leading()
        self.content = content()
        self.trailing = trailing()
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: style.spacing) {
            if (Leading.self != EmptyView.self) {
                leading
                    .font(.system(size: 14, weight: .bold))
            }
            
            content
                .font(.system(size: 16, weight: .semibold))

            if (Trailing.self != EmptyView.self) {
                trailing
                    .font(.system(size: 14, weight: .bold))
            }
        }
        .padding(.vertical, style.verticalPadding)
        .padding(.horizontal, style.horizontalPadding)
        .lineLimit(1)
        .foregroundStyle(style.fgStyle)
        .underline(style.underlined, color: style.fgStyle)
        .background {
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .fill(style.bgStyle)
        }
        .onTapGesture {
            action()
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ForEach(DButtonStyle.allCases, id: \.self) { style in
            DButton(style: style) {
                print("dbutton test press")
            } content: {
                Text("Test DButton")
            } leading: {
                Image(systemName: "message.fill")
            }
        }
        
        DButton(style: .secondary) {
            print("progress btn")
        } content: {
            Text("Doing something")
        } leading: {
            ProgressView()
                .controlSize(.small)
        }
        
        Divider()
        
        HStack(alignment: .bottom) {
            DButton(style: .secondary) {
                print("github")
            } content: {
                Text("GitHub")
            }
            
            DButton(style: .secondary) {
                print("give us feedback")
            } content: {
                Text("Give us Feedback")
            } leading: {
                Image(systemName: "bubble.left.and.bubble.right")
            }
            
            VStack {
                DButton(style: .link) {
                    print("changelog")
                } content: {
                    Text("What's new (1.0.2)")
                } trailing: {
                    Image(systemName: "arrow.up.forward.square")
                }
                
                DButton(style: .primary) {
                    print("update now")
                } content: {
                    Text("Update Now")
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    .padding(48)
    .background {
        DawnColors.primaryBackground
    }
}