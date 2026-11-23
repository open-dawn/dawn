//
//  FlowLayout.swift
//  libdawnUI
//
//  Created by Longhi on 28/10/26.
//

import SwiftUI

public struct FlowLayout: Layout {
    public var spacing: CGFloat

    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = makeLines(proposal: proposal, subviews: subviews)
        let maxWidth = proposal.width ?? lines.map(\.width).max() ?? 0
        let height = lines.reduce(CGFloat(0)) { partial, line in
            partial == 0 ? line.height : partial + spacing + line.height
        }
        return CGSize(width: maxWidth, height: height)
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let lines = makeLines(proposal: proposal, subviews: subviews)
        var currentY = bounds.minY

        for line in lines {
            var currentX = bounds.minX

            for item in line.items {
                let yOffset = (line.height - item.size.height) / 2
                subviews[item.index].place(
                    at: CGPoint(x: currentX, y: currentY + yOffset),
                    proposal: ProposedViewSize(item.size)
                )
                currentX += item.size.width + spacing
            }

            currentY += line.height + spacing
        }
    }

    private struct LineItem {
        let index: Int
        let size: CGSize
    }

    private struct Line {
        var items: [LineItem] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func makeLines(proposal: ProposedViewSize, subviews: Subviews) -> [Line] {
        let maxWidth = proposal.width ?? .infinity
        var lines: [Line] = []
        var currentLine = Line()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = currentLine.items.isEmpty
                ? size.width
                : currentLine.width + spacing + size.width

            if nextWidth > maxWidth, !currentLine.items.isEmpty {
                lines.append(currentLine)
                currentLine = Line()
            }

            currentLine.items.append(LineItem(index: index, size: size))
            currentLine.width = currentLine.items.count == 1
                ? size.width
                : currentLine.width + spacing + size.width
            currentLine.height = max(currentLine.height, size.height)
        }

        if !currentLine.items.isEmpty {
            lines.append(currentLine)
        }

        return lines
    }
}
