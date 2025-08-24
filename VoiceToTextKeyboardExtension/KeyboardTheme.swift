//
//  KeyboardTheme.swift
//  VoiceToTextKeyboardExtension
//
//  Created by Ankit Jain on 24/08/25.
//

import SwiftUI

enum KeyboardTheme: String, CaseIterable, Identifiable {
    case systemDefault
    case minimal
    case highContrast
    case neon

    var id: String { self.rawValue }

    var background: Color {
        switch self {
        case .systemDefault: return Color(UIColor.systemBackground)
        case .minimal: return Color.gray.opacity(0.1)
        case .highContrast: return Color.black
        case .neon: return Color.black
        }
    }

    var buttonColor: Color {
        switch self {
        case .systemDefault: return Color.accentColor
        case .minimal: return Color.blue.opacity(0.6)
        case .highContrast: return Color.yellow
        case .neon: return Color.pink
        }
    }

    var textColor: Color {
        switch self {
        case .systemDefault, .minimal: return .primary
        case .highContrast: return .white
        case .neon: return .green
        }
    }
}
