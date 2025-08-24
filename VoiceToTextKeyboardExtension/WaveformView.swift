//
//  WaveformView.swift
//  VoiceToTextKeyboardExtension
//
//  Created by Ankit Jain on 24/08/25.
//

import Foundation
import SwiftUI

struct WaveformView: View {
    let samples: [CGFloat]        // 0...1
    var body: some View {
        GeometryReader { geo in
            let barCount = samples.count
            let barSpacing: CGFloat = 2
            let totalSpacing = CGFloat(barCount - 1) * barSpacing
            let barWidth = max(2, (geo.size.width - totalSpacing) / CGFloat(barCount))
            HStack(alignment: .center, spacing: barSpacing) {
                ForEach(samples.indices, id: \.self) { i in
                    // Height scales 6px...max (feel free to tweak)
                    let h = max(6, samples[i] * geo.size.height)
                    Capsule()
                        .frame(width: barWidth, height: h)
                        .animation(.linear(duration: 0.05), value: samples[i])
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 60)
        .opacity(0.95)
        .accessibilityHidden(true)
    }
}
