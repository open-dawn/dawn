//
//  DButton+Previews.swift
//  dawn
//
//  Created by Longhi on 20/10/26.
//

#if DEBUG

import SwiftUI

#Preview("DButton Styles") {
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

#endif
